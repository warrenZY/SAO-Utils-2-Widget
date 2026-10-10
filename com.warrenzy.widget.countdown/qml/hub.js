// Cross-instance broadcast bus.
.pragma library

var _listeners = [];
var _nextId = 1;

function subscribe(cb) {
    var id = _nextId++;
    _listeners.push({ id: id, cb: cb });
    return id;
}

function unsubscribe(id) {
    for (var i = 0; i < _listeners.length; ++i) {
        if (_listeners[i].id === id) {
            _listeners.splice(i, 1);
            return;
        }
    }
}

function notify() {
    var snap = _listeners.slice();
    for (var i = 0; i < snap.length; ++i) {
        try { snap[i].cb(); }
        catch (e) { console.warn("[countdown] hub listener failed: " + e); }
    }
}