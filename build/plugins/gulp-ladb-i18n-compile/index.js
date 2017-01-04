var through = require('through2');
var gutil = require('gulp-util');
var yaml = require('js-yaml');
var merge = require('merge');

var markdownIt = require('markdown-it');
var externalLinks = require('markdown-it-external-links');
var md = markdownIt({
    html: true,
    linkify: true,
    typographer: true,
    breaks: true
}).use(externalLinks, {
    externalTarget: '_blank'
});

var PluginError = gutil.PluginError;

module.exports = function (opt) {

    function markownValues(doc) {
        for (var key in doc) {
            if (doc.hasOwnProperty(key)) {
                if (typeof doc[key] == 'string') {
                    doc[key] = md.renderInline(doc[key]);
                } else if (typeof doc[key] == 'object') {
                    markownValues(doc[key]);
                }
            }
        }
    }

    function transform(file, enc, cb) {

        if (file.isNull()) return cb(null, file);
        if (file.isStream()) return cb(new PluginError('gulp-ladb-i18n-compile', 'Streaming not supported'));

        var options = merge({
            safe: false
        }, opt);
        var data;
        try {

            var contents = file.contents.toString('utf8');
            var ymlOptions = { schema: yaml.DEFAULT_FULL_SCHEMA };
            var ymlDocument = options.safe ? yaml.safeLoad(contents, ymlOptions) : yaml.load(contents, ymlOptions);

            markownValues(ymlDocument);

            var filename = file.path.substr(file.base.length);
            var locale = filename.substr(0, filename.length - '.yml'.length);

            var resources = {};
            resources[locale] = {
                translation: ymlDocument
            };
            var i18nextOptions = {
                lng: locale,
                resources: resources
            };

            data = 'i18next.init(' + JSON.stringify(i18nextOptions) + ');';

        } catch (err) {
            return cb(new PluginError('gulp-ladb-i18n-compile', err));
        }

        file.contents = new Buffer(data);
        file.path = file.base + locale + '.js';

        cb(null, file);
    }

    return through.obj(transform);
};