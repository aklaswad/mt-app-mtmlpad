$(function () {

    $('#open-login-panel').click( function () {
        var $panel = $('#sign-in-fields');
        var disp   = $panel.css('display');
        console.log(disp);
        $panel.css( 'display', disp === 'block' ? 'none' : 'block' );
        return false;
    });

});

