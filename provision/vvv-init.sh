#!/usr/bin/env bash

set -eo pipefail

echo " * Custom Site Template Develop Provisioner"
echo "   - This template is great for contributing to WordPress Core!"
echo "   - Not so much for building themes and plugins, or agency/client work"
echo "   - For client/theme/plugin work, use the custom-site-template instead"

DOMAIN=$(get_primary_host "${VVV_SITE_NAME}".test)
SITE_TITLE=$(get_config_value 'site_title' "${DOMAIN}")
WP_TYPE=$(get_config_value 'wp_type' "single")
DB_NAME=$(get_config_value 'db_name' "${VVV_SITE_NAME}")
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e " * Creating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`"
echo -e " * Granting the wp user priviledges to the '${DB_NAME}' database"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e " * DB operations done."

echo " * Setting up the log subfolder for Nginx logs"
noroot mkdir -p "${VVV_PATH_TO_SITE}/log"
noroot touch "${VVV_PATH_TO_SITE}/log/nginx-error.log"
noroot touch "${VVV_PATH_TO_SITE}/log/nginx-access.log"

echo " * Creating public_html folder if it doesn't exist already"
noroot mkdir -p "${VVV_PATH_TO_SITE}/public_html"

echo " * Copying the sites Nginx config template"
if [ -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-custom.conf" ]; then
  echo " * A vvv-nginx-custom.conf file was found"
  cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-custom.conf" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
else
  echo " * Using the default vvv-nginx-default.conf, to customize, create a vvv-nginx-custom.conf"
  cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-default.conf" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
fi

date_time=$(cat /vagrant/provisioned_at)
logfolder="/var/log/provisioners/${date_time}"
gruntlogfile="${logfolder}/provisioner-${VVV_SITE_NAME}-grunt.log"

# Install and configure the latest stable version of WordPress
echo " * Checking for WordPress Installs"
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/src/wp-load.php" ]]; then
  echo " * Checking out WordPress trunk. See https://develop.svn.wordpress.org/trunk"
  noroot svn checkout "https://develop.svn.wordpress.org/trunk/" "${VVV_PATH_TO_SITE}/public_html"
  cd "${VVV_PATH_TO_SITE}/public_html"
  echo " * Running npm install after svn checkout"
  noroot npm install --no-optional
  echo " * Finished npm install"
else
  cd "${VVV_PATH_TO_SITE}/public_html"
  echo " * Updating WordPress trunk. See https://develop.svn.wordpress.org/trunk"
  if [[ -e .svn ]]; then
    echo " * Running svn up"
    noroot svn up
  else
    if [[ $(noroot git rev-parse --abbrev-ref HEAD) == 'master' ]]; then
      echo " * Running git pull --no-edit git://develop.git.wordpress.org/ master"
      noroot git pull --no-edit git://develop.git.wordpress.org/ master
    else
      echo " * Skipped auto git pull on develop.git.wordpress.org since you aren't on the master branch"
    fi
  fi
  echo " * Running npm install after svn up/git pull"
  # Grunt can crash because doesn't find a folder, the workaround is remove the node_modules folder and download all the dependencies again.
  # We create a file with the stderr output of NPM to check if there are errors, if yes we remove the folder and try again npm install.
  noroot npm install --no-optional &> /tmp/dev-npm.txt
  echo " * Checking npm install result"
  if [ "$(grep -c "^$1" /tmp/dev-npm.txt)" -ge 1 ]; then
    echo " ! Issues encounteed, here's the output:"
    cat /tmp/dev-npm.txt
    rm /tmp/dev-npm.txt
    echo " * Removing the node modules folder"
    rm -rf node_modules
    echo " * Clearing npm cache"
    noroot npm cache clean --force
    echo " * Running npm install again"
    noroot npm install --no-optional
    echo " * Completed npm install command, check output for issues"
  fi
  echo " * Finished running npm install"
  echo " * Running grunt"
  echo " * Check the Grunt/Webpack output for Trunk at VVV/log/provisioners/${date_time}/provisioner-${VVV_SITE_NAME}-grunt.log"
  noroot grunt > "${gruntlogfile}" 2>&1 
  if [ $? -ne 0 ]; then
     echo " ! Grunt exited with an error, these are the last 20 lines of the log:"
     tail -20 "${gruntlogfile}"
  fi
fi

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  cd "${VVV_PATH_TO_SITE}/public_html"
  echo " * Configuring WordPress trunk..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --path="${VVV_PATH_TO_SITE}/public_html/src" --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'SCRIPT_DEBUG', true );
PHP

  noroot mv "${VVV_PATH_TO_SITE}/public_html/src/wp-config.php" "${VVV_PATH_TO_SITE}/public_html/wp-config.php"
fi

if ! $(noroot wp core is-installed --path="${VVV_PATH_TO_SITE}/public_html/src"); then
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
fi

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

echo " * Checking for WordPress build"
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html/build" ]]; then
  echo " * Initializing grunt... This may take a few moments."
  cd "${VVV_PATH_TO_SITE}/public_html/"
  echo " * Check the Grunt/Webpack output for Trunk Build at VVV/log/provisioners/${date_time}/provisioner-${NAME}-grunt.log"
  noroot grunt > "${gruntlogfile}" 2>&1 
  if [ $? -ne 0 ]; then
     echo " ! Grunt exited with an error, these are the last 20 lines of the log:"
     tail -20 "${gruntlogfile}"
  fi
  echo " * Grunt initialized."
fi
echo " * Checking mu-plugins folder"
noroot mkdir -p "${VVV_PATH_TO_SITE}/public_html/src/wp-content/mu-plugins" "${VVV_PATH_TO_SITE}/public_html/build/wp-content/mu-plugins"

echo " * Custom site template develop provisioner completed, WP will be served from the build folder, don't forget to rebuild after changes to src"
