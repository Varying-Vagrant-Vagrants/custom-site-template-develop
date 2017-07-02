# VVV Custom site template (develop)
For when you just need a dev site running wordpress develop

## Overview
This template will allow you to create a WordPress dev environment running wordpress develop using only `vvv-custom.yml`.

The supported environments are:
- A single site
- A subdomain multisite
- A subdirectory multisite

# Configuration

### The minimum required configuration:

```
my-site:
  repo: https://github.com/Varying-Vagrant-Vagrants/custom-site-template-develop
  hosts:
    - my-site.dev
```
| Setting    | Value       |
|------------|-------------|
| Domain     | my-site.dev |
| Site Title | my-site.dev |
| DB Name    | my-site     |
| Site Type  | Single      |

### WordPress Multisite with Subdomains:

```
my-site:
  repo: https://github.com/Varying-Vagrant-Vagrants/custom-site-template-develop
  hosts:
    - multisite.dev
    - site1.multisite.dev
    - site2.multisite.dev
  custom:
    wp_type: subdomain
```
| Setting    | Value               |
|------------|---------------------|
| Domain     | multisite.dev       |
| Site Title | multisite.dev       |
| DB Name    | my-site             |
| Site Type  | Subdomain Multisite |

## Configuration Options

```
hosts:
    - foo.dev
    - bar.dev
    - baz.dev
```
Defines the domains and hosts for VVV to listen on. 
The first domain in this list is your sites primary domain.

```
custom:
    site_title: My Awesome Dev Site
```
Defines the site title to be set upon installing WordPress.

```
custom:
    wp_type: single
```
Defines the type of install you are creating.
Valid values are:
- single
- subdomain
- subdirectory

```
custom:
    db_name: super_secet_db_name
```
Defines the DB name for the installation.


