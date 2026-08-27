//
// The notification daemon.
//
// Strata used to run mako for this. Two processes cannot own
// org.freedesktop.Notifications at once, so showing notifications in the shell
// means being the daemon rather than decorating someone else's — see ADR-0012.
//
// Loaded through a Loader on purpose: if this file fails, the rest of the shell
// keeps working and the bar simply shows no bell.
//
import Quickshell.Services.Notifications
import QtQuick

Item {
    id: root

    // Set from Prefs. Do-not-disturb suppresses the toast, never the record:
    // the notification is still kept and still counted, so nothing is lost.
    property bool dnd: false

    readonly property var list: server.trackedNotifications
                                ? server.trackedNotifications.values : []
    readonly property int count: list.length

    signal posted(var notification)

    // Arrival times, keyed by notification id. The specification gives a
    // notification no timestamp, so a panel that wants to say "20m ago" has to
    // remember when it saw one. A plain object rather than a property that
    // things bind to: it is read once when a card is created, never watched.
    property var stamps: ({})

    function stampOf(id) {
        const t = root.stamps[id];
        return t !== undefined ? t : Date.now();
    }

    NotificationServer {
        id: server

        // Notifications belong to the session, not to this process. Dropping
        // them on every config reload would mean a saved file wipes the list.
        keepOnReload: true

        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: notification => {
            // Without this the notification is closed as soon as the signal
            // handler returns.
            notification.tracked = true;
            root.stamps[notification.id] = Date.now();
            if (!root.dnd)
                root.posted(notification);
        }
    }

    // Ids accumulate for as long as the session lives. Sweeping the ones that
    // are no longer tracked keeps that from being a slow leak.
    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: {
            const live = {};
            const l = root.list;
            for (let i = 0; i < l.length; i++) live[l[i].id] = root.stamps[l[i].id];
            root.stamps = live;
        }
    }

    function dismissAll() {
        const l = root.list.slice();
        for (let i = 0; i < l.length; i++) {
            try { l[i].dismiss(); } catch (e) { /* already gone */ }
        }
    }
}
