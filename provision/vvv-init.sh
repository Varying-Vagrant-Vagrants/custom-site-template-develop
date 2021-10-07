#!/usr/bin/env bash

set -eo pipefail

DOMAIN=$(get_primary_host "${VVV_SITE_NAME}".test)
SITE_TITLE=$(get_config_value 'site_title' "${DOMAIN}")
WP_TYPE=$(get_config_value 'wp_type' "single")
DB_NAME=$(get_config_value 'db_name' "${VVV_SITE_NAME}")
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}
VCS=$(get_config_value 'vcs' '')

if [[ -f "${VVV_PATH_TO_SITE}/public_html/.svn" && "${VCS}" == "git" ]] || [[ "${VVV_PATH_TO_SITE}/public_html/.git" && "${VCS}" == "svn" ]]; then
  echo " * Warning: The VCS is set to ${VCS} but this doesn't match the existing repo, you need to manually migrate from svn to git or vice versa, VVV won't do it automatically to avoid data loss"
fi

if [[ -z "${VCS}" ]]; then
  echo " * vcs value was not set in the config, checking for existing version control"
  if [[ -f "${VVV_PATH_TO_SITE}/public_html/.svn" ]]; then
    echo " * A .svn folder was found, using svn"
    VCS="svn"
  elif [[ -f "${VVV_PATH_TO_SITE}/public_html/.git" ]]; then
    echo " * An existing .git folder was found, using git"
    VCS="git"
  else
    echo " * Defaulting to an svn checkout"
    VCS="svn"
  fi
else
  echo " * Using ${VCS} for version control"
fi

# -------------------------------------------------------

function setup_database() {
  # Make a database, if we don't already have one
  echo -e " * Creating database '${DB_NAME}' (if it's not already there)"
  mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`"
  echo -e " * Granting the wp user priviledges to the '${DB_NAME}' database"
  mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO wp@localhost IDENTIFIED BY 'wp';"
  echo -e " * DB operations done."
}

function setup_nginx_folders() {
  echo " * Setting up the log subfolder for Nginx logs"
  noroot mkdir -p "${VVV_PATH_TO_SITE}/log"
  noroot touch "${VVV_PATH_TO_SITE}/log/nginx-error.log"
  noroot touch "${VVV_PATH_TO_SITE}/log/nginx-access.log"

  echo " * Creating public_html folder if it doesn't exist already"
  noroot mkdir -p "${VVV_PATH_TO_SITE}/public_html"
}

function prepare_nginx_conf() {
  echo " * Copying the sites Nginx config template"
  if [ -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-custom.conf" ]; then
    echo " * A vvv-nginx-custom.conf file was found"
    cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-custom.conf" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
  else
    echo " * Using the default vvv-nginx-default.conf, to customize, create a vvv-nginx-custom.conf"
    cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-default.conf" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
  fi
}

function handle_svn_wp() {
  if [[ ! -e .svn ]]; then
    echo " * Checking out WordPress trunk. See https://develop.svn.wordpress.org/trunk"
    noroot svn checkout "https://develop.svn.wordpress.org/trunk/" "${VVV_PATH_TO_SITE}/public_html"
  else
    echo " * Updating WordPress trunk. See https://develop.svn.wordpress.org/trunk"
    echo " * Running svn up"
    noroot svn up
  fi
}

function handle_git_wp() {
    if [[ ! -e .git ]]; then
        echo " * Checking out WordPress trunk. See https://develop.git.wordpress.org/"
        noroot git clone git://develop.git.wordpress.org/ .
    fi
    if [[ $(noroot git rev-parse --abbrev-ref HEAD) == 'master' ]]; then
      echo " * Running git pull --no-edit git://develop.git.wordpress.org/ master"
      noroot git pull --no-edit git://develop.git.wordpress.org/ master
    else
      echo " * Skipped auto git pull on develop.git.wordpress.org since you aren't on the master branch"
      noroot git fetch --all
    fi
}

function configure_wp() {
  echo " * Configuring WordPress trunk..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --path="${VVV_PATH_TO_SITE}/public_html/src" --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'SCRIPT_DEBUG', true );
PHP

  noroot mv "${VVV_PATH_TO_SITE}/public_html/src/wp-config.php" "${VVV_PATH_TO_SITE}/public_html/wp-config.php"
}

function maybe_install_wp() {
  if $(noroot wp core is-installed --path="${VVV_PATH_TO_SITE}/public_html/src"); then
    return 0
  fi
  cd "${VVV_PATH_TO_SITE}"
  echo " * Installing WordPress trunk..."

  if [ "${WP_TYPE}" = "subdomain" ]; then
    INSTALL_COMMAND="multisite-install --subdomains"
  elif [ "${WP_TYPE}" = "subdirectory" ]; then
    INSTALL_COMMAND="multisite-install"
  else
    INSTALL_COMMAND="install"
  fi

  noroot wp core "${INSTALL_COMMAND}" --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=admin --admin_email="admin@local.test" --admin_password="password" --path="${VVV_PATH_TO_SITE}/public_html/src"
  echo " * WordPress Source was installed at ${VVV_PATH_TO_SITE}/public_html/src, with the username 'admin', and the password 'password'"
}

function try_npm_install() {
  echo " * Running npm install after svn up/git pull"
  # Grunt can crash because doesn't find a folder, the workaround is remove the node_modules folder and download all the dependencies again.
  npm_config_loglevel=error noroot npm install --no-optional
  echo " * Checking npm install result"
  if [ $? -eq 1 ]; then
    echo " ! Issues encounteed, here's the output:"
    echo " * Removing the node modules folder"
    rm -rf node_modules
    echo " * Clearing npm cache"
    npm_config_loglevel=error noroot npm cache clean --force
    echo " * Running npm install again"
    npm_config_loglevel=error noroot npm install --no-optional
    echo " * Completed npm install command, check output for issues"
  fi
  echo " * Finished running npm install"
}

function try_grunt_build() {
  echo " * Running grunt"
  noroot grunt
  if [ $? -ne 1 ]; then
     echo " ! Grunt exited with an error"
  fi
}

function check_for_wp_importer() {
  echo " * Setting up the WP importer"
  if [[ ! -d "${VVV_PATH_TO_SITE}/public_html" ]]; then
    cd "${VVV_PATH_TO_SITE}/public_html/tests/phpunit/data/plugins/"
    if [[ -e 'wordpress-importer/.svn' ]]; then
      cd 'wordpress-importer'
      echo " * Running svn up on WP importer"
      noroot svn up
    else
      echo " * Running svn checkout for WP importer"
      noroot svn checkout https://plugins.svn.wordpress.org/wordpress-importer/tags/0.6.3/ wordpress-importer
    fi
    cd "${VVV_PATH_TO_SITE}"
  fi
}

# -------------------------------------------------------

echo " * Custom Site Template Develop Provisioner"
echo "   - This template is great for contributing to WordPress Core!"
echo "   - Not so much for building themes and plugins, or agency/client work"
echo "   - For client/theme/plugin work, use the custom-site-template instead"

setup_database
setup_nginx_folders
prepare_nginx_conf

# Install and configure the latest stable version of WordPress
echo " * Checking for WordPress Installs"

cd "${VVV_PATH_TO_SITE}/public_html"
if [[ "${VCS}" == "svn" ]]; then
  handle_svn_wp
else
  handle_git_wp
fi

try_npm_install
try_grunt_build

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  configure_wp
fi

maybe_install_wp
check_for_wp_importer

echo " * Checking for WordPress build"
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html/src" ]]; then
  echo " * Initializing grunt... This may take a few moments."
  cd "${VVV_PATH_TO_SITE}/public_html/"
  try_grunt_build
  echo " * Grunt initialized."
fi

echo " * Checking mu-plugins folder"
noroot mkdir -p "${VVV_PATH_TO_SITE}/public_html/src/wp-content/mu-plugins" "${VVV_PATH_TO_SITE}/public_html/build/wp-content/mu-plugins"

echo " * Custom site template develop provisioner completed, WP will be served from the build folder, don't forget to rebuild after changes to src"
