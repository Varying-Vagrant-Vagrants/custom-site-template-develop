# VVV Custom site template (WP Core development)

This site template is a great way to test the bleeding edge versions of WordPress, or contribute to development of WordPress core. Ideal for contributor days, Trac tickets, etc

For general WP work such as theme building or plugin development, use the normal custom site template instead. Only use this if you want the bleeding edge trunk version of WordPress.

## Overview

This template will allow you to create a WordPress core dev environment running wordpress trunk using only `config/config.yml`.

The supported environments are:

- A single site
- A subdomain multisite
- A subdirectory multisite

## Pulling In Updates

This template will attempt to update on provision, but if that fails, you can enter the `public_html` folder and manually update. This can be done using `svn up` if SVN is used, and `git pull` if git is used. GUI tools such as TortoiseSVN, Visual Studio Code, and other GUIs, can be used to update the folder too.

## Switching from SVN to Git

```shell
vagrant ssh
cd /srv/www/[wordpress-trunk] # the folder name 
./bin/develop_git
```

Running this command will convert an svn based checkout to git and will require some time to run.

## Configuration

### Options

| Key         | Default                    | Description                                                                                       |
|-------------|----------------------------|---------------------------------------------------------------------------------------------------|
| `db_name`    | The sites name             | The name of the MySQL database to create and install to                                           |
| `site_title` | The first host of the site | The title of the site after install                                                               |
| `vcs`        | `svn`                      | The type of WP checkout to make when first creating the site, valid values are `svn` and `git`    |
| `wp_type`    | `single`                   | Defines what kind of site gets installed, `subdomain` `subdirectory` or `single` are valid values |
| `npm`    | `true`                   | Execute NPM during the provision |

### The Minimum Required Configuration

```yaml
my-site:
  repo: https://github.com/Varying-Vagrant-Vagrants/custom-site-template-develop
  hosts:
    - my-site.test
```

This settings will use as default SVN to download WordPress-develop but it is possible to switch to git:

<table>
<thead>
  <tr>
    <th>Site in <code>config.yml</code></th>
    <th>Setting</th>
    <th>Value</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td rowspan="4">
<pre lang="yaml">
my-site:
  repo: https://github.com/Varying-Vagrant-Vagrants/custom-site-template-develop
  hosts:
    - my-site.test
  custom:
    vcs: git # using 'svn' will force this vcs
</pre>
    </td>
    <td>Domain</td>
    <td>my-site.test</td>
  </tr>
  <tr>
    <td>Site Title</td>
    <td>my-site.test</td>
  </tr>
  <tr>
    <td>DB Name</td>
    <td>my-site</td>
  </tr>
  <tr>
    <td>Site Type</td>
    <td>Single</td>
  </tr>
</tbody>
</table>

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
