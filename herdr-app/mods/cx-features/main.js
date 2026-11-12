// CultureX switcher (cmd-k). Three groups, each sorted by most recent session:
//
//   Features  folders in ~/CultureX/features
//   Repos     ~/CultureX/repos/{cx-saas-server, cx-creator-services, cx-analytics-backend, cx-worker}
//   Spaces    every open Herdr space
//
// Enter goes to the most recent agent session (e.g. Claude) already running
// inside that folder or space. With none, a feature goes to its cx-<feature>
// space, or builds it with automation/culturex/herdr-feature.sh (plain shells,
// no agents); a repo goes to a shell already open there, or opens a new space
// with an empty shell; a space is selected. Nothing here starts an agent, so
// the Agents list only shows sessions you started. Tab toggles starting dev
// servers on a feature build, ctrl+d closes the row's space, Esc leaves.
//
// Spaces are named after their feature or repo (an older cx-<feature> name
// still counts). Each gets a fixed colour (shared "space.colors"), so the
// sidebar, tab picker and this list agree.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, ScrollHandle } from "gpui-base";
import { exec, home, spaces, agents, panes, run, theme, props, closeOverlay, shared, setShared, notify } from "herdr";

const FEATURES = `${home()}/CultureX/features`;
const REPOS = `${home()}/CultureX/repos`;
const BUILD = `${home()}/Personal/dotfiles/automation/culturex/herdr-feature.sh`;

// Repos a feature can have worktrees of (chips on feature rows).
const REPO_LABELS = {
  "cx-saas-server": "server",
  "cx-worker": "worker",
  "cx-creator-services": "creator",
  "cx-analytics-backend": "analytics",
  "cx-saas-dashboard": "dashboard",
  "saas-super-admin": "admin",
};
// Main clones listed under Repos.
const MAIN_REPOS = ["cx-saas-server", "cx-creator-services", "cx-analytics-backend", "cx-worker"];

// Catppuccin Mocha accents. A feature keeps the same colour every time it opens:
// pinned here, else picked from its name.
const PALETTE = ["#cba6f7", "#fab387", "#a6e3a1", "#89dceb", "#f5c2e7", "#f9e2af", "#89b4fa", "#f38ba8", "#94e2d5", "#b4befe"];
const PINNED = {};
// How the shipped mods draw the theme colour names they give spaces.
const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

function colorFor(feature) {
  if (PINNED[feature]) return PINNED[feature];
  let h = 0;
  for (const ch of feature) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return PALETTE[h % PALETTE.length];
}

function spaceColor(t, id) {
  const c = (shared("space.colors") ?? {})[id] ?? "ansi6";
  return c.startsWith("#") ? c : (MARK[c] ?? t[c] ?? t.dim);
}

// The feature or repo a space belongs to, by its name.
function ownerOf(name, known) {
  if (known.has(name)) return name;
  if (name?.startsWith("cx-") && known.has(name.slice(3))) return name.slice(3);
  return null;
}

// Keep every feature and repo space on its colour.
function applyColors(known) {
  const cur = shared("space.colors") ?? {};
  const next = { ...cur };
  let changed = false;
  for (const s of spaces()) {
    const owner = ownerOf(s.name, known);
    if (!owner) continue;
    const want = colorFor(owner);
    if (next[s.id] !== want) {
      next[s.id] = want;
      changed = true;
    }
  }
  if (changed) setShared("space.colors", next);
}

const inside = (cwd, dir) => Boolean(cwd) && (cwd === dir || cwd.startsWith(dir + "/"));
const byRecent = (a, b) => b.seq - a.seq;

// Agent sessions running inside dir, most recent first.
function sessionsIn(dir) {
  const cwdOf = new Map(panes().map((p) => [p.pane, p.cwd]));
  return agents().filter((a) => inside(cwdOf.get(a.pane), dir)).sort(byRecent);
}

// One line per feature ("F name"), per repo checkout in it
// ("R feature repo branch dirty"), and per main clone ("M repo branch dirty").
const SCAN = `
features="$1"; repos="$2"; shift 2
state() { b=$(git -C "$1" branch --show-current 2>/dev/null); d=$(git -C "$1" status --porcelain 2>/dev/null | wc -l | tr -d ' '); printf '%s\\t%s' "$b" "$d"; }
for f in "$features"/*/; do
  f="\${f%/}"; n="\${f##*/}"
  printf 'F\\t%s\\n' "$n"
  for r in "$@"; do
    [ -e "$f/$r/.git" ] && printf 'R\\t%s\\t%s\\t%s\\n' "$n" "$r" "$(state "$f/$r")"
  done
done
for r in ${MAIN_REPOS.join(" ")}; do
  [ -e "$repos/$r/.git" ] && printf 'M\\t%s\\t%s\\n' "$r" "$(state "$repos/$r")"
done
`;

export default class Features extends View {
  init(_props, cx) {
    this.filter = "";
    this.features = null;
    this.repos = [];
    this.at = 0;
    this.dev = false;
    this.busy = null;
    this.scroll = ScrollHandle.new();
    this.handle = cx.focus_handle();
    this.input = InputState.new({ placeholder: "Go to a feature, repo or space…" });
    this.input.on("change", (_e, cx) => {
      this.filter = this.input.value();
      this.at = 0;
      cx.notify();
    });
    this.input.on("submit", (_e, cx) => this.open(this.items()[this.at], cx));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    cx.spawn(async (cx) => {
      await this.load();
      cx.notify();
    });
  }

  async load() {
    try {
      const r = await exec("bash", ["-c", SCAN, "scan", FEATURES, REPOS, ...Object.keys(REPO_LABELS)], { timeout: 20000 });
      const byName = new Map();
      const repos = [];
      for (const line of r.stdout.split("\n")) {
        const [kind, a, b, c, d] = line.split("\t");
        if (kind === "F") byName.set(a, { kind: "feature", name: a, dir: `${FEATURES}/${a}`, repos: [] });
        else if (kind === "R") byName.get(a)?.repos.push({ repo: b, branch: c, dirty: Number(d) || 0 });
        else if (kind === "M") repos.push({ kind: "repo", name: a, dir: `${REPOS}/${a}`, branch: b, dirty: Number(c) || 0 });
      }
      this.features = [...byName.values()];
      this.repos = repos;
    } catch (e) {
      this.features = [];
      this.error = String(e);
    }
  }

  close() {
    closeOverlay(props().overlay);
  }

  known() {
    return new Set([...(this.features ?? []).map((f) => f.name), ...MAIN_REPOS]);
  }

  spaceOf(item) {
    if (!item) return null;
    if (item.kind === "space") return spaces().find((s) => s.id === item.id);
    return spaces().find((s) => s.name === item.name || s.name === `cx-${item.name}`);
  }

  // The groups, filtered, each sorted by most recent session (then name).
  groups() {
    const q = this.filter.toLowerCase();
    const sort = (list) =>
      list
        .filter((x) => !q || x.name.toLowerCase().includes(q))
        .sort((a, b) => (b.sessions[0]?.seq ?? -1) - (a.sessions[0]?.seq ?? -1) || a.name.localeCompare(b.name));
    const withSessions = (x) => ({ ...x, sessions: sessionsIn(x.dir) });
    const all = agents();
    const open = spaces().map((s) => ({
      kind: "space",
      id: s.id,
      name: s.name,
      branch: s.branch,
      active: s.active,
      sessions: all.filter((a) => a.space === s.id).sort(byRecent),
    }));
    return [
      { title: "Features", items: sort((this.features ?? []).map(withSessions)) },
      { title: "Repos", items: sort(this.repos.map(withSessions)) },
      { title: "Spaces", items: sort(open) },
    ].filter((g) => g.items.length);
  }

  items() {
    return this.groups().flatMap((g) => g.items);
  }

  open(item, cx) {
    if (!item || this.busy) return;
    const recent = item.sessions?.[0];
    if (recent) {
      this.close();
      run("agent.focus", { terminal: recent.address });
      return;
    }
    if (item.kind === "repo") {
      this.close();
      const own = this.spaceOf(item);
      const shell = panes().find((p) => p.terminal && inside(p.cwd, item.dir));
      if (own) run("space.select", { id: own.id });
      else if (shell) run("pane.focus", { pane: shell.pane });
      else run("space.new", { name: item.name, folder: item.dir });
      return;
    }
    const s = this.spaceOf(item);
    if (s) {
      this.close();
      run("space.select", { id: s.id });
      return;
    }
    this.busy = item.name;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const r = await exec(BUILD, [item.name, ...(this.dev ? ["--dev"] : [])], { timeout: 90000 });
        if (r.code !== 0) throw new Error(r.stderr.trim() || `exit ${r.code}`);
        applyColors(this.known());
        this.close();
      } catch (e) {
        this.busy = null;
        notify({ title: `Couldn't open ${item.name}`, body: String(e.message ?? e), level: "error" });
        cx.notify();
      }
    });
  }

  closeSpace(item) {
    const s = this.spaceOf(item);
    if (!s) return;
    this.close();
    run("space.close", { id: s.id }); // Herdr asks before ending its terminals.
  }

  glyph(t, st) {
    if (st === "working") return svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900);
    return div().w(12).flex_none().text_color(t[st] ?? t.dim).child(st === "idle" ? "○" : st ? "●" : "·");
  }

  // Right side: where Enter goes.
  where(t, item) {
    if (this.busy === item.name) {
      return h_flex().flex_none().gap(6).items_center().text_size(11).text_color(t.working)
        .child(svg("mods/workspace-chrome/spinner.svg").size(12).spin(900)).child("opening…");
    }
    const recent = item.sessions[0];
    if (recent) {
      const more = item.sessions.length > 1 ? ` +${item.sessions.length - 1}` : "";
      const label = item.kind === "space" ? recent.program?.name ?? "agent" : `${recent.program?.name ?? "agent"} · ${recent.space_name}`;
      return h_flex().flex_none().gap(6).items_center().text_size(11).text_color(t.muted)
        .child(this.glyph(t, recent.status))
        .child(label + more);
    }
    const s = this.spaceOf(item);
    if (s) return div().flex_none().text_size(11).text_color(t.muted).child(s.active ? "here" : "space open");
    return div().flex_none().text_size(11).text_color(t.dim).child(item.kind === "repo" ? "new shell" : "new space");
  }

  badge(t, item) {
    const tile = (bg) => h_flex().size(22).flex_none().rounded(6).bg(bg).items_center().justify_center();
    if (item.kind === "repo") return tile(colorFor(item.name)).child(svg("icons/git.svg").size(13).text_color("#11111b"));
    const bg = item.kind === "feature" ? colorFor(item.name) : spaceColor(t, item.id);
    return tile(bg).text_size(11).font_bold().text_color("#11111b").child([...item.name][0]?.toUpperCase() ?? "?");
  }

  row(t, item, on) {
    const isFeature = item.kind === "feature";
    const dirty = isFeature ? item.repos.reduce((n, r) => n + r.dirty, 0) : item.dirty ?? 0;
    const sub = isFeature
      ? [...new Set(item.repos.map((r) => r.branch).filter(Boolean))].join(" · ") || "no worktrees"
      : item.branch || "";
    const live = Boolean(item.sessions[0] || this.spaceOf(item));
    return h_flex()
      .id(`cxf-${item.kind}-${item.id ?? item.name}`)
      .mx(4)
      .px(10)
      .h(44)
      .flex_none()
      .gap(10)
      .items_center()
      .rounded(7)
      .cursor_pointer()
      .when(on, (el) => el.bg(t.hover))
      .hover((st) => st.bg(t.hover))
      .on_click((_e, cx) => this.open(item, cx))
      .child(this.badge(t, item))
      .child(
        v_flex().flex_1().min_w(0).gap(2)
          .child(
            h_flex().gap(6).items_center()
              .child(div().text_color(t.foreground).when(live, (d) => d.font_semibold()).child(item.name))
              .when(isFeature, (el) => el.children(item.repos.map((r) =>
                div().px(5).rounded(4).bg(t.raised).text_size(10.5).text_color(t.muted).child(REPO_LABELS[r.repo] ?? r.repo)))),
          )
          .child(div().truncate().text_size(11).text_color(t.dim).child(sub)),
      )
      .when(dirty > 0, (el) => el.child(div().flex_none().text_size(11).text_color(t.ansi3).child(`${dirty} dirty`)))
      .child(this.where(t, item));
  }

  render() {
    applyColors(this.known());
    const t = theme();
    const groups = this.groups();
    const items = groups.flatMap((g) => g.items);
    this.at = Math.max(0, Math.min(this.at, items.length - 1));
    const sel = items[this.at];
    const hint = (k, label) => h_flex().gap(4).child(div().px(5).rounded(4).bg(t.raised).text_color(t.muted).child(k)).child(label);

    // One flat list: group titles (24px) and rows (44px); scroll_to_item counts both.
    const list = [];
    const rowIndex = new Map();
    for (const g of groups) {
      list.push(div().h(24).flex_none().px(14).pt(6).text_size(11).font_semibold().text_color(t.dim).child(g.title));
      for (const item of g.items) {
        rowIndex.set(item, list.length);
        list.push(this.row(t, item, item === sel));
      }
    }
    const height = groups.length * 24 + items.length * 44;

    let enterLabel = "open";
    if (sel?.sessions[0]) enterLabel = "go to session";
    else if (this.spaceOf(sel)) enterLabel = "go";

    return v_flex()
      .id("cx-features")
      .track_focus(this.handle)
      .w_full()
      .min_h(0)
      .p(18)
      .gap(10)
      .bg(t.popover)
      .text_size(13)
      .on_key_down((e, cx) => {
        const k = e.key;
        if (k === "escape") return this.close();
        if (k === "down" && items.length) this.at = (this.at + 1) % items.length;
        else if (k === "up" && items.length) this.at = (this.at + items.length - 1) % items.length;
        else if (k === "tab") this.dev = !this.dev;
        else if (k === "d" && e.modifiers.control) return this.closeSpace(sel);
        else return;
        const i = rowIndex.get(items[this.at]);
        if (i !== undefined) this.scroll.scroll_to_item(i);
        cx.stop_propagation();
        cx.notify();
      })
      .child(
        h_flex().items_center().gap(8)
          .child(div().flex_1().text_size(15).font_semibold().text_color(t.foreground).child("CultureX"))
          .child(
            h_flex().id("cxf-dev").gap(6).px(8).py(3).rounded(6).items_center().cursor_pointer()
              .text_size(11.5).text_color(this.dev ? t.foreground : t.dim)
              .bg(this.dev ? t.raised : t.popover)
              .hover((s) => s.bg(t.hover))
              .on_click((_e, cx) => { this.dev = !this.dev; cx.notify(); })
              .child(div().size(7).rounded(4).bg(this.dev ? t.done : t.dim))
              .child(this.dev ? "dev servers: start" : "dev servers: off"),
          )
          .child(div().id("cxf-esc").px(6).py(2).rounded(5).text_size(11).text_color(t.dim).cursor_pointer()
            .hover((s) => s.bg(t.hover).text_color(t.foreground)).on_click(() => this.close()).child("Esc")),
      )
      .child(
        h_flex().h(36).flex_none().px(10).gap(8).items_center().rounded(9).border_1().border_color(t.accent).bg(t.background)
          .child(svg("mods/workspace-chrome/search.svg").size(15).text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground)),
      )
      .child(v_flex().flex_none().child(
        this.features === null
          ? h_flex().h(44).px(10).gap(8).items_center().text_color(t.dim)
              .child(svg("mods/workspace-chrome/spinner.svg").size(12).spin(900)).child("Reading features…")
          : items.length === 0
            ? div().px(10).py(12).text_color(t.dim).child(this.error ? `Couldn't read ${FEATURES}: ${this.error}` : "Nothing matches.")
            : v_flex().id("cxf-list").h(Math.min(480, height)).flex_none().overflow_y_scrollbar().track_scroll(this.scroll)
                .children(list),
      ))
      .child(
        h_flex().gap(14).pt(4).border_t(1).border_color(t.border).text_size(11).text_color(t.dim)
          .child(hint("↵", enterLabel))
          .child(hint("Tab", "dev servers"))
          .child(hint("ctrl+d", "close space")),
      );
  }
}
