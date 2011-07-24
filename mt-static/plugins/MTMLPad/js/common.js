$(function () {
    $('#open-login-panel').click( function () {
        var $panel = $('#signin-panel');
        var disp   = $panel.css('display');
        if ( disp === 'none' ) {
          $('#signin-panel').show();
          $(window).bind( 'click.close_login', function () {
              $(window).unbind( 'click.close_login' );
              $('#signin-panel').hide();
          });
          return false;
        }
        else {
          $(window).unbind( 'click.close_login' );
          $('#signin-panel').hide();
        }
    });

    $('#openid_url').click( function () {
        return false;
    });

    $('#open-usermenu-panel').click( function () {
        $('#usermenu-panel').show();
        $(window).bind( 'click.close_usermenu', function () {
            $(window).unbind( 'click.close_usermenu' );
            $('#usermenu-panel').hide();
        });
        return false;
    });
});

