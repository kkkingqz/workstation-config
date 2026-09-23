import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const TA_UUIDS = [
    'tiling-assistant@ubuntu.com',
    'tiling-assistant@leleat-on-github',
];

class FreeSpaceSelector {
    constructor(owner, rects, monitor, onSelect) {
        this._owner = owner;
        this._rects = rects;
        this._monitor = monitor;
        this._onSelect = onSelect;

        this._index = this._largestIndex();
        this._grab = null;
        this._root = null;
        this._shade = null;
        this._highlight = null;
        this._label = null;
    }

    _largestIndex() {
        let best = 0;
        let bestArea = -1;

        for (let i = 0; i < this._rects.length; i++) {
            const r = this._rects[i];
            const area = r.width * r.height;

            if (area > bestArea) {
                bestArea = area;
                best = i;
            }
        }

        return best;
    }

    open() {
        const monitorRect = global.display.get_monitor_geometry(this._monitor);

        this._shade = new St.Widget({
            x: monitorRect.x,
            y: monitorRect.y,
            width: monitorRect.width,
            height: monitorRect.height,
            reactive: false,
            style: 'background-color: rgba(0, 0, 0, 0.20);',
        });

        this._highlight = new St.Widget({
            reactive: false,
            style:
                'border: 4px solid rgba(53, 132, 228, 1.0); ' +
                'background-color: rgba(53, 132, 228, 0.14); ' +
                'border-radius: 12px;',
        });

        this._label = new St.Label({
            style:
                'background-color: rgba(0, 0, 0, 0.84); ' +
                'color: white; padding: 8px 12px; ' +
                'border-radius: 10px; font-weight: bold;',
        });

        this._root = new St.Widget({
            reactive: true,
            can_focus: true,
            x: monitorRect.x,
            y: monitorRect.y,
            width: monitorRect.width,
            height: monitorRect.height,
        });

        Main.uiGroup.add_child(this._shade);
        Main.uiGroup.add_child(this._highlight);
        Main.uiGroup.add_child(this._label);
        Main.uiGroup.add_child(this._root);

        this._root.connect('key-press-event', (_actor, event) =>
            this._onKeyPress(event));

        this._grab = Main.pushModal(this._root);
        this._root.grab_key_focus();

        this._render();
    }

    destroy() {
        if (this._grab) {
            Main.popModal(this._grab);
            this._grab = null;
        }

        this._root?.destroy();
        this._shade?.destroy();
        this._highlight?.destroy();
        this._label?.destroy();

        this._root = null;
        this._shade = null;
        this._highlight = null;
        this._label = null;

        if (this._owner._selector === this)
            this._owner._selector = null;
    }

    _center(rect) {
        return {
            x: rect.x + rect.width / 2,
            y: rect.y + rect.height / 2,
        };
    }

    _move(dx, dy) {
        const current = this._center(this._rects[this._index]);

        let bestIndex = -1;
        let bestScore = Number.POSITIVE_INFINITY;

        for (let i = 0; i < this._rects.length; i++) {
            if (i === this._index)
                continue;

            const candidate = this._center(this._rects[i]);
            const vx = candidate.x - current.x;
            const vy = candidate.y - current.y;

            let primary;
            let secondary;

            if (dx < 0) {
                if (vx >= 0)
                    continue;
                primary = -vx;
                secondary = Math.abs(vy);
            } else if (dx > 0) {
                if (vx <= 0)
                    continue;
                primary = vx;
                secondary = Math.abs(vy);
            } else if (dy < 0) {
                if (vy >= 0)
                    continue;
                primary = -vy;
                secondary = Math.abs(vx);
            } else {
                if (vy <= 0)
                    continue;
                primary = vy;
                secondary = Math.abs(vx);
            }

            const score = primary + secondary * 0.35;

            if (score < bestScore) {
                bestScore = score;
                bestIndex = i;
            }
        }

        if (bestIndex !== -1) {
            this._index = bestIndex;
            this._render();
        }
    }

    _render() {
        const rect = this._rects[this._index];

        this._highlight.set_position(rect.x, rect.y);
        this._highlight.set_size(rect.width, rect.height);

        this._label.text =
            `Free space ${this._index + 1}/${this._rects.length}   ` +
            '← ↑ ↓ →   Enter/Space';

        const monitorRect =
            global.display.get_monitor_geometry(this._monitor);

        const [, naturalWidth] =
            this._label.get_preferred_width(-1);
        const [, naturalHeight] =
            this._label.get_preferred_height(-1);

        const x = monitorRect.x +
            Math.max(16, Math.floor((monitorRect.width - naturalWidth) / 2));

        this._label.set_position(x, monitorRect.y + 24);
        this._label.set_size(naturalWidth, naturalHeight);
    }

    _onKeyPress(event) {
        const key = event.get_key_symbol();

        if (key === Clutter.KEY_Left) {
            this._move(-1, 0);
            return Clutter.EVENT_STOP;
        }

        if (key === Clutter.KEY_Right) {
            this._move(1, 0);
            return Clutter.EVENT_STOP;
        }

        if (key === Clutter.KEY_Up) {
            this._move(0, -1);
            return Clutter.EVENT_STOP;
        }

        if (key === Clutter.KEY_Down) {
            this._move(0, 1);
            return Clutter.EVENT_STOP;
        }

        if (key === Clutter.KEY_Escape) {
            this.destroy();
            return Clutter.EVENT_STOP;
        }

        if (key === Clutter.KEY_Return ||
            key === Clutter.KEY_KP_Enter ||
            key === Clutter.KEY_space) {
            const rect = this._rects[this._index];

            this.destroy();
            this._onSelect(rect);

            return Clutter.EVENT_STOP;
        }

        return Clutter.EVENT_STOP;
    }
}

export default class SmartPopupExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._selector = null;
        this._ta = null;

        Main.wm.addKeybinding(
            'smart-popup',
            this._settings,
            Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
            Shell.ActionMode.NORMAL,
            () => {
                this._openSmartPopup().catch(error => {
                    logError(error, `${this.uuid}: Smart Popup failed`);

                    Main.notify(
                        'Smart Tiling Popup',
                        'Failed. Check GNOME Shell journal.'
                    );
                });
            }
        );
    }

    disable() {
        Main.wm.removeKeybinding('smart-popup');

        this._selector?.destroy();
        this._selector = null;
        this._ta = null;
        this._settings = null;
    }

    async _getTilingAssistant() {
        if (this._ta)
            return this._ta;

        let taExtension = null;
        let taUuid = null;

        for (const candidate of TA_UUIDS) {
            const extension = Extension.lookupByUUID(candidate);

            if (extension) {
                taExtension = extension;
                taUuid = candidate;
                break;
            }
        }

        if (!taExtension) {
            throw new Error(
                `Tiling Assistant is not loaded; tried: ${TA_UUIDS.join(', ')}`
            );
        }

        console.log(
            `${this.uuid}: using Tiling Assistant ${taUuid} at ${taExtension.path}`
        );

        const baseUri = Gio.File
            .new_for_path(taExtension.path)
            .get_uri();

        const [
            twmModule,
            utilityModule,
            popupModule,
        ] = await Promise.all([
            import(`${baseUri}/src/extension/tilingWindowManager.js`),
            import(`${baseUri}/src/extension/utility.js`),
            import(`${baseUri}/src/extension/tilingPopup.js`),
        ]);

        const Twm = twmModule.TilingWindowManager;

        // We intentionally use Tiling Assistant's already-loaded singleton.
        // If this is a different/uninitialized module instance, fail safely.
        if (!Twm._signals || !Twm._tileGroups) {
            throw new Error(
                'Tiling Assistant singleton is not initialized/shared'
            );
        }

        this._ta = {
            extension: taExtension,
            Twm,
            Rect: utilityModule.Rect,
            Popup: popupModule.TilingSwitcherPopup,
        };

        return this._ta;
    }

    async _openSmartPopup() {
        this._selector?.destroy();
        this._selector = null;

        const {
            extension,
            Twm,
            Rect,
            Popup,
        } = await this._getTilingAssistant();

        const focused = global.display.focus_window;

        const monitor =
            focused?.get_monitor() ??
            global.display.get_current_monitor();

        const tileGroup = Twm.getTopTileGroup({monitor});

        if (!tileGroup.length) {
            Main.notify(
                'Smart Tiling Popup',
                'No visible tiled window group on this monitor.'
            );
            return;
        }

        const occupiedRects = tileGroup
            .filter(window =>
                window.get_monitor() === monitor &&
                window.isTiled &&
                window.tiledRect)
            .map(window => window.tiledRect);

        if (!occupiedRects.length) {
            Main.notify(
                'Smart Tiling Popup',
                'No tiled rectangles are available.'
            );
            return;
        }

        const workspace =
            global.workspace_manager.get_active_workspace();

        const workArea = new Rect(
            workspace.get_work_area_for_monitor(monitor)
        );

        const freeRects = workArea
            .minus(occupiedRects)
            .filter(rect =>
                rect.width >= 120 &&
                rect.height >= 120);

        if (!freeRects.length) {
            Main.notify(
                'Smart Tiling Popup',
                'There is no free tiled space.'
            );
            return;
        }

        const taSettings = extension.getSettings(
            'org.gnome.shell.extensions.tiling-assistant'
        );

        const allWorkspaces = taSettings.get_boolean(
            'tiling-popup-all-workspace'
        );

        const candidates = Twm
            .getWindows(allWorkspaces)
            .filter(window => !tileGroup.includes(window));

        if (!candidates.length) {
            Main.notify(
                'Smart Tiling Popup',
                'There are no other windows available.'
            );
            return;
        }

        const openPopup = rect => {
            const popup = new Popup(
                candidates,
                rect,
                false
            );

            if (!popup.show(tileGroup)) {
                popup.destroy();

                Main.notify(
                    'Smart Tiling Popup',
                    'No selectable windows are available.'
                );

                return;
            }

            popup.connect('closed', (_popup, canceled) => {
                if (canceled || !popup.tiledWindow)
                    return;

                Twm.updateTileGroup([
                    popup.tiledWindow,
                    ...tileGroup,
                ]);
            });
        };

        if (freeRects.length === 1) {
            openPopup(freeRects[0]);
            return;
        }

        this._selector = new FreeSpaceSelector(
            this,
            freeRects,
            monitor,
            rect => openPopup(rect)
        );

        this._selector.open();
    }
}
