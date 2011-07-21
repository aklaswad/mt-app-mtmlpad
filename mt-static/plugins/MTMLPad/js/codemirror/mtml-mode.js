(function(){

var re_mtignore_start = RegExp('^<m' + 't:?ignore>', 'i');
var re_mtignore_end   = RegExp('</m' + 't:?ignore[^>]*?>', 'i');
var re_mttag_start    = RegExp('^<[/$]?m' + 't:?[\\w:]+', 'i');
var re_mttag_end      = RegExp('^[-/$]*?>', 'i');
var re_mttag_attr     = RegExp('^[\\w:]+\\s*=\\s*');
var re_mttag_name     = RegExp('^[\\w:]+');
var re_mttag_vatom    = '(<[^>]+?>|"(<[^>]+?>|.)*?"|\'(<[^>]+?>|.)*?\'|\\w+)'
var re_mttag_value    = RegExp('^' + re_mttag_vatom + '([:,]' + re_mttag_vatom + ')*' );

CodeMirror.defineMode("mtml", function(config, parserConfig) {
    return {
	startState: function() {
	    return {
		inIgnore: false,
		tag:      null,
	    };
	},
	token: function(stream, state) {
	    if ( state.inIgnore ) {
		if ( stream.match(re_mtignore_end) )
		    state.inIgnore = false;
                else
                    stream.skipToEnd();

		return 'mt-comment';
	    }
	    else if ( state.tag ) {
		stream.eatSpace();
		if ( state.tag == 'tag' ) {
		    if ( stream.match(re_mttag_end) ) {
			state.tag = null;
			return 'mttag';
		    }
		    else if ( stream.match(re_mttag_attr) ) {
			state.tag = 'attr';
			return 'mttag mttag-attr';
		    }
		    else if ( stream.match(re_mttag_name) ) {
			return 'mttag mttag-attr';
		    }
		}
		else if ( state.tag == 'attr' ) {
		    if ( stream.match(re_mttag_value) ) {
			state.tag = 'tag';
			return 'mttag mttag-value';
		    }
		}
		stream.skipToEnd();
		return 'mttag';
	    }
	    else {
		if (stream.match(re_mtignore_start)) {
		    state.inIgnore = true;
		    return "mt-comment";
		}
		if (stream.match(re_mttag_start)) {
		    state.tag = 'tag';
		    return "mttag";
		}
		stream.eat(/[^>]*/);
		return null;
	    }
	}
    };
});

CodeMirror.defineMode("mtmloverlay", function(config, parserConfig) {
    return CodeMirror.overlayParser(
	CodeMirror.getMode(config, parserConfig.backdrop || modeName("html")),
	CodeMirror.getMode(config, 'mtml'),
    true
    );
});

})();
