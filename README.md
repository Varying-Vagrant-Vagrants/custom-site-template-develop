# VVV Custom site template (WP Core development)

For when you just need to work on WordPress Core itself. Great for contributor days, Trac tickets, etc

For general WP work such as theme building or plugin development, use the normal site template instead.

## Overview

This template will allow you to create a WordPress core dev environment running wordpress trunk using only `config/config.yml`.

The supported environments are:

- A single site
- A subdomain multisite
- A subdirectory multisite

## Configuration

### The Minimum Required Configuration

```yaml
my-site:
  repo: https://github.com/Varying-Vagrant-Vagrants/custom-site-template-develop
  hosts:
    - my-site.test
```

| Setting    | Value        |
|------------|--------------|
| Domain     | my-site.test |
| Site Title | my-site.test |
| DB Name    | my-site      |
| Site Type  | Single       |

### WordPress Multisite with Subdomains

```yaml
my-site:
  repo: https://github.com/Varying-Vagrant-Vagrants/custom-site-template-develop
  hosts:
    - multisite.test
    - site1.multisite.test
    - site2.multisite.test
  custom:
    wp_type: subdomain
```

| Setting    | Value               |
|------------|---------------------|
| Domain     | multisite.test      |
| Site Title | multisite.test      |
| DB Name    | my-site             |
| Site Type  | Subdomain Multisite |

## Configuration Options

```yaml
hosts:
    - foo.test
    - bar.test
    - baz.test
```

Defines the domains and hosts for VVV to listen on. The first domain in this list is your sites primary domain.

```yaml
custom:
    site_title: My Awesome Dev Site
```

Defines the site title to be set upon installing WordPress.

```yaml
custom:
    wp_type: single
```

Defines the type of install you are creating. Valid values are:

- single
- subdomain
- subdirectory

```yaml
custom:
    db_name: super_secet_db_name
```

Defines the DB name for the installation.
