<?php

namespace VVV\Custom_Site_Template_Develop;

class ENV_SWITCH {

	function __construct() {
		add_action( 'admin_bar_menu', [ $this, 'admin_bar' ], 9999 );
		add_action( 'wp_footer', [ $this, 'admin_bar_script' ], 9999 );
		add_action( 'admin_footer', [ $this, 'admin_bar_script' ], 9999 );
	}

	function _get_current_env() {
		if ( ! empty ( $_COOKIE['vvv_env'] ) ) {
			return $_COOKIE['vvv_env'];
		}

		return 'src';
	}

	function admin_bar() {
		global $wp_admin_bar;

		$wp_admin_bar->add_menu( array(
			'parent' => 'top-secondary',
			'id'     => 'vvv_switch_env',
			'title'  => "VVV Env: " . ucfirst( $this->_get_current_env() ),
		) );

		$wp_admin_bar->add_menu( array(
			'parent' => 'vvv_switch_env',
			'id'     => 'vvv_switch_env-clear',
			'title'  => "Clear Cookie",
			'href'   => '#'
		) );

		$wp_admin_bar->add_menu( array(
			'parent' => 'vvv_switch_env',
			'id'     => 'vvv_switch_env-src',
			'title'  => "Switch to src",
			'href'   => '#'
		) );

		$wp_admin_bar->add_menu( array(
			'parent' => 'vvv_switch_env',
			'id'     => 'vvv_switch_env-build',
			'title'  => "Switch to build",
			'href'   => '#'
		) );
	}

	function get_cookie_string( $env ) {
		$string = "vvv_env=" . $env . ";";

		if ( defined( COOKIE_DOMAIN ) ) {
			$string .= "domain=" . COOKIE_DOMAIN . ";";
		}

		if ( defined( COOKIEPATH ) ) {
			$string .= "path=" . COOKIEPATH . ";";
		}

		return $string;
	}

	function admin_bar_script() {
		?>
        <script>
            (function () {

                function getCookie(cname) {
                    var name = cname + "=";
                    var ca = document.cookie.split(';');
                    for(var i = 0; i < ca.length; i++) {
                        var c = ca[i];
                        while (c.charAt(0) == ' ') {
                            c = c.substring(1);
                        }
                        if (c.indexOf(name) == 0) {
                            return c.substring(name.length, c.length);
                        }
                    }
                    return "";
                }

                var clear = document.getElementById('wp-admin-bar-vvv_switch_env-clear');
                var src = document.getElementById('wp-admin-bar-vvv_switch_env-src');
                var build = document.getElementById('wp-admin-bar-vvv_switch_env-build');

                if (getCookie("vvv_env")  === '') {
                    console.log("VVV Env cookie not set (using src)");
                } else {
                    console.log("VVV Env cookie set to " + getCookie("vvv_env"));
                }


                clear.onclick = function () {
                    document.cookie = "<?php echo $this->get_cookie_string( null ) ?>";
                    location.reload();
                };

                src.onclick = function () {
                    document.cookie = "<?php echo $this->get_cookie_string( 'src' ) ?>";
                    location.reload();
                };

                build.onclick = function () {
                    document.cookie = "<?php echo $this->get_cookie_string( 'build' ) ?>";
                    location.reload();
                };
            })();
        </script>
		<?php
	}
}

$env_switch = new ENV_SWITCH();
