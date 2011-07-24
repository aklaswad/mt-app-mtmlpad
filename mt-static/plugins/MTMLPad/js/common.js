$(function () {
    $('#open-login-panel').click( function () {
        $('#signin-panel').show();
        $(window).bind( 'click.close_login', function () {
            $(window).unbind( 'click.close_login' );
            $('#signin-panel').hide();
        });
        return false;
    });
});

$(function () {
    $('#open-usermenu-panel').click( function () {
        $('#usermenu-panel').show();
        $(window).bind( 'click.close_usermenu', function () {
            $(window).unbind( 'click.close_usermenu' );
            $('#usermenu-panel').hide();
        });
        return false;
    });
});

