$(document).ready(function () {
    var qs = window.location.search.substring(1);
    var pairs = qs.split('&');
    var args = {};
    var pieces;

    for (i=0;i<pairs.length;i++) {
        pieces = pairs[i].split('=');
        args[pieces[0]] = unescape(pieces[1]);
    }

    if ('apikey' in args && args['apikey'] !== null) {
        $("#apikey").val(args['apikey']);
        getFilings();
    }

    $("#updateNow").bind('click', function () {
        getFilings();
    });

    $("#notify").bind('click', function () {
        requestPermission(function(){});
    });

});

var shown = []

var getFilings = function () {
    var url = 'http://api.nytimes.com/svc/elections/us/v3/finances/2012/filings.json',
        result,
        klass,
        from,
        to,
        notify = false,
        committee_id,
        now,
        time;

    if ($("#notify:checked").val() !== undefined) {
        notify = true;
    }

    $.ajax({dataType: 'jsonp',
            url: url, 
            data: {'api-key': $("#apikey").val()},
            success: function (data) {
                results = data['results'];
                results.reverse();
                for (i=0;i<results.length;i++) {
                    result = results[i];
                    if ($.inArray(result['fec_uri'], shown) > -1) {
                        continue;
                    }

                    shown.push(result['fec_uri']);

                    if (shown.length % 2 === 0) {
                        klass = 'even';
                    } else {
                        klass = 'odd';
                    }
                    if (i == results.length-1) {
                        klass += ' topRow';
                    }

                    from = result['date_coverage_from'] ? result['date_coverage_from'] : '';
                    to = result['date_coverage_to'] ? result['date_coverage_to'] : '';
                    committee_id = result['fec_committee_id'];
                    raised = result['receipts_total'];

                    now = new Date();
                    time = now.getHours() + ':' + now.getMinutes()

                    $("#filings tbody").prepend(
                          '<tr class="' + klass + '"><td>'
                        + '<a href="http://images.nictusa.com/cgi-bin/fecimg/?' + committee_id + '">'
                        + result['committee_name']
                        + '</a>'
                        + '</td><td>'
                        + result['form_type']
                        + '</td><td>'
                        + '<a href="'
                        + result['fec_uri']
                        + '">'
                        + result['report_title']
                        + '</a></td><td>'
                        + from
                        + '</td><td>'
                        + to
                        + '</td><td>'
                        + raised
                        + '</td>'
                        + '<td class="time">'
                        + time
                        + '</td>'
                        + '</tr>'
                    );
                    if (notify === true) {
                        showNotification(result['committee_name'], result['report_title']);
                    }
                }
            }
        });
        setTimeout('getFilings()', 600000);
};

// Notification code from http://www.phpguru.org/html5-webkit-desktop-notifications-example
/**
* Request permission to show desktop notifications.
*/
var requestPermission = function (callback) {
    window.webkitNotifications.requestPermission(callback);
}

/**
* Show notification.
*/
var showNotification = function (title, msg) {
    if (!window.webkitNotifications) {
        alert('Sorry - no support for desktop notifications found. Try Google Chrome.');
    }

    if (window.webkitNotifications.checkPermission() > 0) {
        requestPermission(showNotification);
    }

    // Show the popup
    icon = 'http://query.nictusa.com/images/fec1.gif'
    var popup = window.webkitNotifications.createNotification(icon, title, msg);
    popup.show();
}
