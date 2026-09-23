import GLib from 'gi://GLib';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as DND from 'resource:///org/gnome/shell/ui/dnd.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const HOVER_DELAY_MS = 1300;
const DOCK_CONTAINER_NAME = 'dashtodockContainer';

export default class WorkstationDockSpringExtension extends Extension {
    enable() {
        this._dragActive = false;

        this._hoverApp = null;
        this._hoverAppId = null;
        this._hoverTimeoutId = 0;

        this._dragMonitor = {
            dragMotion: event => this._onDragMotion(event),
        };

        DND.addDragMonitor(this._dragMonitor);

        this._dragBeginId = Main.xdndHandler.connect('drag-begin', () => {
            this._dragActive = true;
            this._resetHover();
        });

        this._dragEndId = Main.xdndHandler.connect('drag-end', () => {
            this._dragActive = false;
            this._resetHover();
        });

        console.log(
            `[${this.uuid}] enabled v3; running-app-only; hover delay=${HOVER_DELAY_MS}ms`
        );
    }

    disable() {
        this._dragActive = false;
        this._resetHover();

        if (this._dragMonitor) {
            DND.removeDragMonitor(this._dragMonitor);
            this._dragMonitor = null;
        }

        if (this._dragBeginId) {
            Main.xdndHandler.disconnect(this._dragBeginId);
            this._dragBeginId = 0;
        }

        if (this._dragEndId) {
            Main.xdndHandler.disconnect(this._dragEndId);
            this._dragEndId = 0;
        }

        console.log(`[${this.uuid}] disabled`);
    }

    _onDragMotion(event) {
        // React only to external application drag-and-drop.
        // Internal Shell/Dock drags are untouched.
        if (!this._dragActive || event.source !== Main.xdndHandler) {
            this._resetHover();
            return DND.DragMotionResult.CONTINUE;
        }

        const app = this._findUbuntuDockApp(event.targetActor);

        if (!app) {
            this._resetHover();
            return DND.DragMotionResult.CONTINUE;
        }

        const appId = this._safeAppId(app);
        if (!appId) {
            this._resetHover();
            return DND.DragMotionResult.CONTINUE;
        }

        // Do absolutely nothing for applications without an existing window.
        // In particular: do not launch a pinned-but-not-running application.
        if (!this._chooseWindow(app)) {
            this._resetHover();
            return DND.DragMotionResult.CONTINUE;
        }

        // Still hovering the same running app: preserve the current timer.
        if (this._hoverAppId === appId)
            return DND.DragMotionResult.CONTINUE;

        this._resetHover();

        this._hoverApp = app;
        this._hoverAppId = appId;

        this._hoverTimeoutId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            HOVER_DELAY_MS,
            () => {
                this._hoverTimeoutId = 0;

                if (!this._dragActive ||
                    !this._hoverApp ||
                    this._hoverAppId !== appId)
                    return GLib.SOURCE_REMOVE;

                // Re-evaluate at timeout time: the app may have closed while
                // the pointer was hovering over the icon.
                const window = this._chooseWindow(this._hoverApp);

                if (!window) {
                    console.log(
                        `[${this.uuid}] skip ${appId}: no running window`
                    );
                    return GLib.SOURCE_REMOVE;
                }

                this._activateWindow(window, appId);
                return GLib.SOURCE_REMOVE;
            }
        );

        return DND.DragMotionResult.CONTINUE;
    }

    _chooseWindow(app) {
        let windows = [];

        try {
            windows = app.get_windows?.() ?? [];
        } catch (e) {
            return null;
        }

        windows = windows.filter(window => {
            if (!window)
                return false;

            try {
                if (window.is_override_redirect?.())
                    return false;
            } catch (e) {
                // Keep the window if the API is unavailable.
            }

            try {
                if (window.skip_taskbar)
                    return false;
            } catch (e) {
                // Keep the window if the property is unavailable.
            }

            return true;
        });

        if (windows.length === 0)
            return null;

        const activeWorkspace =
            global.workspace_manager.get_active_workspace();

        // Prefer a window on the current workspace, then the most recently
        // used one. If the app only has windows elsewhere, Main.activateWindow()
        // will switch workspace and focus the selected window.
        windows.sort((a, b) => {
            const aCurrent = this._isOnWorkspace(a, activeWorkspace) ? 1 : 0;
            const bCurrent = this._isOnWorkspace(b, activeWorkspace) ? 1 : 0;

            if (aCurrent !== bCurrent)
                return bCurrent - aCurrent;

            return this._windowUserTime(b) - this._windowUserTime(a);
        });

        return windows[0] ?? null;
    }

    _activateWindow(window, appId) {
        if (!this._dragActive)
            return;

        try {
            Main.activateWindow(window, global.get_current_time());

            console.log(
                `[${this.uuid}] spring-focused ${appId}`
            );
        } catch (e) {
            console.error(
                `[${this.uuid}] failed to focus ${appId}: ${e}`
            );
        }
    }

    _findUbuntuDockApp(targetActor) {
        if (!targetActor)
            return null;

        let actor = targetActor;
        let candidateApp = null;
        let insideUbuntuDock = false;

        while (actor) {
            try {
                if (actor.get_name?.() === DOCK_CONTAINER_NAME)
                    insideUbuntuDock = true;
            } catch (e) {
                // Actor does not expose a useful name.
            }

            if (!candidateApp) {
                candidateApp = this._extractApp(actor);

                if (!candidateApp && actor._delegate)
                    candidateApp = this._extractApp(actor._delegate);
            }

            actor = actor.get_parent?.() ?? null;
        }

        return insideUbuntuDock ? candidateApp : null;
    }

    _extractApp(object) {
        if (!object)
            return null;

        const app = object.app ?? null;
        if (!app)
            return null;

        if (typeof app.get_id !== 'function' ||
            typeof app.get_windows !== 'function')
            return null;

        return app;
    }

    _safeAppId(app) {
        try {
            return app.get_id?.() ?? null;
        } catch (e) {
            return null;
        }
    }

    _windowUserTime(window) {
        try {
            return window.get_user_time?.() ?? 0;
        } catch (e) {
            return 0;
        }
    }

    _isOnWorkspace(window, workspace) {
        try {
            return window.get_workspace?.() === workspace;
        } catch (e) {
            return false;
        }
    }

    _resetHover() {
        if (this._hoverTimeoutId) {
            GLib.source_remove(this._hoverTimeoutId);
            this._hoverTimeoutId = 0;
        }

        this._hoverApp = null;
        this._hoverAppId = null;
    }
}
