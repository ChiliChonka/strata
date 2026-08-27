//
// Fire-and-forget shell commands.
//
// Quickshell.execDetached is the right tool: nothing here wants the output, and
// several of these commands (poweroff, lock) outlive the shell that started
// them. It is called through a try/catch with a Process fallback so that a
// Quickshell build without it degrades instead of taking the service down —
// a missing method throws when called, not when the file loads.
//
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    function run(cmd) {
        try {
            Quickshell.execDetached(["sh", "-c", cmd]);
            return;
        } catch (e) {
            // fall through
        }
        if (!fallback.running) {
            fallback.command = ["sh", "-c", cmd];
            fallback.running = true;
        }
    }

    // Same, but the arguments are passed positionally so nothing has to be
    // quoted into the script. Inside `cmd`, "$1" is the first extra argument.
    function runWith(cmd, args) {
        // Built up rather than concatenated: an array literal in QML is not
        // always a plain JS array to the tooling, and push is unambiguous.
        const argv = ["sh", "-c", cmd, "strata"];
        for (let i = 0; i < args.length; i++) argv.push(args[i]);
        try {
            Quickshell.execDetached(argv);
            return;
        } catch (e) {
            // fall through
        }
        if (!fallback.running) {
            fallback.command = argv;
            fallback.running = true;
        }
    }

    Process { id: fallback }
}
