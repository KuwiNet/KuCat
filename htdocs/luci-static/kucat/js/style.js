/*
 *  luci-theme-kucat
 *  Copyright (C) 2021-2026 The Sirpdboy Team <herboy2008@gmail.com> 
 *
 *  Have a bug? Please create an issue here on GitHub!
 *      https://github.com/sirpdboy/luci-theme-kucat/issues
 *
 *  Licensed to the public under the Apache License 2.0
 */

/* KuWiNet: String.prototype.format compatibility shim.
 * Some LuCI plugin front-ends (e.g. kucat-config / advancedplus) rely on
 * `'...'.format(...)` / `_('...').format(...)`.  Newer LuCI (24.10) no longer
 * guarantees String.prototype.format, which caused sporadic
 * "TypeError: _(...).format is not a function".  Inject it globally here so
 * every page has it before any dependent script runs.
 */
if (!String.prototype.format) {
    String.prototype.format = function() {
        var args = arguments, n = 0;
        return this.replace(/%[sdif]|%%/g, function(m) {
            if (m == '%%') return '%';
            if (n >= args.length) return m;
            var v = args[n++];
            if (v === undefined || v === null) return '';
            if (m == '%d') return parseInt(v, 10) || 0;
            if (m == '%f') return parseFloat(v) || 0;
            return String(v);
        });
    };
}

 function pdopenbar() {
    var leftBar = document.getElementById("header-bar-left");
    var rightBar = document.getElementById("header-bar-right");
    
    leftBar.style.cssText = "width:300px;display:block !important";
    rightBar.style.cssText = "width:0;display:none !important";
}

function pdclosebar() {
    var leftBar = document.getElementById("header-bar-left");
    var rightBar = document.getElementById("header-bar-right");
    
    leftBar.style.cssText = "width:0;display:none !important";
    rightBar.style.cssText = "width:50px;display:block !important";
}

document.addEventListener('DOMContentLoaded', function() {
    document.addEventListener('keydown', function(e) {
        if (e.ctrlKey && e.key === 'ArrowLeft') pdopenbar();
        if (e.ctrlKey && e.key === 'ArrowRight') pdclosebar();
    });
});
