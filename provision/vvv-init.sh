#!/usr/bin/env bash

echo "Custom Site Template Develop Provisioner - use this template for WP Core development. For client work, use the custom-site-template instead"

DOMAIN=`get_primary_host "${VVV_SITE_NAME}".test`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
WP_TYPE=`get_config_value 'wp_type' "single"`
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
echo -e "\nGranting the wp user priviledges to the '${DB_NAME}' database"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

echo "Setting up the log subfolder for Nginx logs"
noroot mkdir -p ${VVV_PATH_TO_SITE}/log
noroot touch ${VVV_PATH_TO_SITE}/log/nginx-error.log
noroot touch ${VVV_PATH_TO_SITE}/log/nginx-access.log

# Install and configure the latest stable version of WordPress
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/src/wp-load.php" ]]; then
  echo "Checking out WordPress trunk. See https://develop.svn.wordpress.org/trunk"
  noroot svn checkout "https://develop.svn.wordpress.org/trunk/" "${VVV_PATH_TO_SITE}/public_html"
  cd "${VVV_PATH_TO_SITE}/public_html"
  echo "Running npm install"
  noroot npm install --no-optional
else
  cd "${VVV_PATH_TO_SITE}/public_html"
  echo "Updating WordPress trunk. See https://develop.svn.wordpress.org/trunk"
  if [[ -e .svn ]]; then
    echo "Running svn up"
    noroot svn up
  else
    if [[ $(noroot git rev-parse --abbrev-ref HEAD) == 'master' ]]; then
      echo "running git pull --no-edit git://develop.git.wordpress.org/ master"
      noroot git pull --no-edit git://develop.git.wordpress.org/ master
    else
      echo "Skipped auto git pull on develop.git.wordpress.org since you aren't on the master branch"
    fi
  fi
  echo "Running npm install"
  noroot npm install --no-optional &> /tmp/dev-npm.txt
  if [ "$(grep -c "^$1" /tmp/dev-npm.txt)" -ge 1 ]; then
    rm -rf node_modules
    noroot npm install --no-optional
  fi
  echo "Running grunt"
  noroot grunt
fi

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  cd "${VVV_PATH_TO_SITE}/public_html"
  echo "Configuring WordPress trunk..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --path="${VVV_PATH_TO_SITE}/public_html/src" --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'SCRIPT_DEBUG', true );
PHP
  
  mv "${VVV_PATH_TO_SITE}/public_html/src/wp-config.php" "${VVV_PATH_TO_SITE}/public_html/wp-config.php"
fi

if ! $(noroot wp core is-installed --path="${VVV_PATH_TO_SITE}/public_html/src"); then
  cd ${VVV_PATH_TO_SITE}
  echo "Installing WordPress trunk..."

  if [ "${WP_TYPE}" = "subdomain" ]; then
    INSTALL_COMMAND="multisite-install --subdomains"
  elif [ "${WP_TYPE}" = "subdirectory" ]; then
    INSTALL_COMMAND="multisite-install"
  else
    INSTALL_COMMAND="install"
  fi

  noroot wp core ${INSTALL_COMMAND} --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=admin --admin_email="admin@local.test" --admin_password="password" --path="${VVV_PATH_TO_SITE}/public_html/src"
  echo "WordPress Source was installed at ${VVV_PATH_TO_SITE}/public_html/src, with the username 'admin', and the password 'password'"
fi

echo "Setting up the WP importer"
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html" ]]; then
  cd "${VVV_PATH_TO_SITE}/public_html/tests/phpunit/data/plugins/"
  if [[ -e 'wordpress-importer/.svn' ]]; then
    cd 'wordpress-importer'
    noroot svn up
  else
    noroot svn checkout https://plugins.svn.wordpress.org/wordpress-importer/tags/0.6.3/ wordpress-importer
  fi
  cd ${VVV_PATH_TO_SITE}
fi

echo "Checking for WordPress build"
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html/build" ]]; then
  echo "Initializing grunt... This may take a few moments."
  cd "${VVV_PATH_TO_SITE}/public_html/"
  noroot grunt
  echo "Grunt initialized."
fi
echo "Checking mu-plugins folder"
noroot mkdir -p "${VVV_PATH_TO_SITE}/public_html/src/wp-content/mu-plugins" "${VVV_PATH_TO_SITE}/public_html/build/wp-content/mu-plugins"

echo "Copying Nginx template"
cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"

echo "Adjusting TLS key values in Nginx template"
if [ -n "$(type -t is_utility_installed)" ] && [ "$(type -t is_utility_installed)" = function ] && `is_utility_installed core tls-ca`; then
  VVV_CERT_DIR="/srv/certificates"
  # On VVV 2.x we don't have a /srv/certificates mount, so switch to /vagrant/certificates
  codename=$(lsb_release --codename | cut -f2)
  if [[ $codename == "trusty" ]]; then # VVV 2 uses Ubuntu 14 LTS trusty
    VVV_CERT_DIR="/vagrant/certificates"
  fi
  sed -i "s#{{TLS_CERT}}#ssl_certificate ${VVV_CERT_DIR}/${VVV_SITE_NAME}/dev.crt;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
  sed -i "s#{{TLS_KEY}}#ssl_certificate_key ${VVV_CERT_DIR}/${VVV_SITE_NAME}/dev.key;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
else
    sed -i "s#{{TLS_CERT}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
    sed -i "s#{{TLS_KEY}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
fi

echo "Custom site template develop provisioner completed, WP will be served from the build folder"
