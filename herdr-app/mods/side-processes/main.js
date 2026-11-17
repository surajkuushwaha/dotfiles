// Processes tab for the dev layout's side panel: every local Herdr terminal with the
// memory its whole process tree uses, heaviest first. Clicking a row jumps to it (the
// arrow lists its child processes), Stop ends only
// the program it runs (the shell and tab stay), Close ends the terminal.
// Refreshes every 5 s, only while the tab is shown.
import { View, div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { run, exec, hc, layout, terminals, panes, spaces, theme } from "herdr";

const STACK = "side-body";
const SELF = "side-processes";
const SHELLS = new Set(["zsh", "bash", "sh", "fish", "login", "env"]);
const SHOW_CHILD_MB = 20;
const ARM_MS = 3000;

const base = (path) => path.split("/").pop();
const mb = (kb) => kb >= 1024 * 1024 ? `${(kb / 1048576).toFixed(1)} GB` : `${Math.round(kb / 1024)} MB`;

function find(node, id) {
  if (!node || typeof node !== "object") return null;
  if (node.id === id) return node;
  for (const child of node.children ?? []) {
    const hit = find(child, id);
    if (hit) return hit;
  }
  return null;
}

// A process's short name: the program, plus its title when it set one ("next-server (v16)").
function label(command) {
  const first = command.split(" ")[0];
  return command.startsWith("/") || !command.includes("(") ? base(first) : command.slice(0, 40);
}

function parsePs(text) {
  const procs = new Map(), kids = new Map();
  for (const line of text.split("\n")) {
    const m = /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.*)$/.exec(line);
    if (!m) continue;
    const [pid, ppid, rss] = [+m[1], +m[2], +m[3]];
    procs.set(pid, { pid, ppid, rss, name: label(m[4].trim()) });
    if (!kids.has(ppid)) kids.set(ppid, []);
    kids.get(ppid).push(pid);
  }
  return { procs, kids };
}

export default class Processes extends View {
  init(_props, cx) {
    this.pids = {};        // terminal address -> its shell's pid (stable for the terminal)
    this.rows = [];
    this.open = new Set();
    this.armed = null;     // "<action>:<address>" waiting for a second click
    this.refresh(cx);
    cx.timer.every(5000, (cx) => this.refresh(cx));
  }

  shown() {
    const root = layout();
    return find(root, "side-panel")?.hidden !== true && find(root, STACK)?.active === SELF;
  }

  refresh(cx, force = false) {
    if (this.busy || (!force && this.rows.length && !this.shown())) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        const local = terminals().filter((t) => t.state === "live" && !String(t.address).includes("/"));
        await Promise.all(local.filter((t) => !this.pids[t.address]).map(async (t) => {
          const r = await hc(["get", t.address]);
          if (r.code === 0) this.pids[t.address] = JSON.parse(r.stdout).pid;
        }));
        const ps = await exec("ps", ["-axo", "pid=,ppid=,rss=,command="]);
        const { procs, kids } = parsePs(ps.stdout);
        const total = (pid) => (procs.get(pid)?.rss ?? 0) + (kids.get(pid) ?? []).reduce((s, k) => s + total(k), 0);
        const tree = (pid, out = []) => {
          for (const k of kids.get(pid) ?? []) { out.push(procs.get(k)); tree(k, out); }
          return out;
        };
        const where = this.places();
        this.rows = local.map((t) => {
          const pid = this.pids[t.address], shell = procs.get(pid);
          if (!shell) return null;
          const all = tree(pid);
          // The program it runs: the heaviest process under the shell that isn't a shell.
          const main = all.filter((p) => !SHELLS.has(p.name)).sort((a, b) => b.rss - a.rss)[0] ?? null;
          return {
            address: t.address,
            where: where[t.address] ?? (t.labels?.["herdr.panel"] ? "side panel" : ""),
            name: t.program?.name ?? main?.name ?? shell.name,
            status: t.status ?? null,
            kb: total(pid),
            main,
            children: all.filter((p) => p.rss >= SHOW_CHILD_MB * 1024).sort((a, b) => b.rss - a.rss),
          };
        }).filter(Boolean).sort((a, b) => b.kb - a.kb);
        this.error = null;
      } catch (e) {
        this.error = String(e);
      } finally {
        this.busy = false;
        cx.notify();
      }
    });
  }

  // "space / tab" for every terminal shown in a pane.
  places() {
    const tabs = {};
    for (const s of spaces()) for (const tab of s.tabs ?? []) tabs[tab.id] = `${s.name} / ${tab.name}`;
    const out = {};
    for (const p of panes()) if (p.terminal) out[p.terminal] = tabs[p.tab];
    return out;
  }

  // Shows the tab holding this terminal.
  reveal(address) {
    const pane = panes().find((p) => p.terminal === address);
    if (!pane) return run("terminal.peek", { terminal: address });
    const space = spaces().find((s) => (s.tabs ?? []).some((tab) => tab.id === pane.tab));
    if (space) run("space.select", { id: space.id });
    run("tab.select", { id: pane.tab });
    run("pane.focus", { terminal: address });
  }

  // First click arms the action, a second click within 3 s runs it.
  confirm(key, cx, action) {
    if (this.armed === key) { this.armed = null; action(); this.refresh(cx, true); return; }
    this.armed = key;
    cx.timer.after(ARM_MS, (cx) => { if (this.armed === key) { this.armed = null; cx.notify(); } });
    cx.notify();
  }

  stop(row) {
    if (row.main) exec("kill", [String(row.main.pid)]);
  }

  close(row) {
    run("terminal.kill", { terminal: row.address });
  }

  cleanup() {
    for (const row of this.idle()) this.close(row);
  }

  idle() {
    return this.rows.filter((r) => r.status === "done" || r.status === "idle");
  }

  button(id, text, cx, onClick, { danger = false, armed = false } = {}) {
    const t = theme();
    return div().id(id).px(6).h(20).flex().items_center().rounded(4).cursor_pointer().text_size(11)
      .text_color(armed ? t.background : danger ? t.blocked : t.muted)
      .when(armed, (e) => e.bg(t.blocked))
      .hover((s) => s.bg(armed ? t.blocked : t.hover))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); })
      .child(text);
  }

  row(r, cx) {
    const t = theme(), expanded = this.open.has(r.address);
    const dot = { working: t.working, blocked: t.blocked, done: t.done, idle: t.idle }[r.status];
    const stopKey = `stop:${r.address}`, closeKey = `close:${r.address}`;
    return v_flex().id(`row-${r.address}`).px(10).py(6).gap(2).border_b(1).border_color(t.border)
      .hover((s) => s.bg(t.hover)).cursor_pointer()
      .on_click(() => this.reveal(r.address))
      .child(h_flex().gap(8).items_center()
        .child(div().id(`fold-${r.address}`).w(14).text_color(t.dim).cursor_pointer().hover((s) => s.text_color(t.foreground))
          .on_click((_e, cx) => { cx.stop_propagation(); expanded ? this.open.delete(r.address) : this.open.add(r.address); cx.notify(); })
          .child(expanded ? "▾" : "▸"))
        .child(div().w(8).h(8).rounded(4).bg(dot ?? t.border))
        .child(div().flex_1().min_w(0).truncate().text_color(t.foreground).child(r.name))
        .child(div().text_color(r.kb > 512 * 1024 ? t.blocked : t.foreground).font_semibold().child(mb(r.kb))))
      .child(h_flex().gap(4).items_center()
        .child(div().flex_1().min_w(0).truncate().text_size(11).text_color(t.dim)
          .child(`${r.address}${r.where ? ` · ${r.where}` : ""}${r.status ? ` · ${r.status}` : ""}`))
        .when(Boolean(r.main), (e) => e.child(this.button(`stop-${r.address}`, this.armed === stopKey ? "Stop?" : "Stop", cx,
          (cx) => this.confirm(stopKey, cx, () => this.stop(r)), { armed: this.armed === stopKey })))
        .child(this.button(`close-${r.address}`, this.armed === closeKey ? "Close?" : "Close", cx,
          (cx) => this.confirm(closeKey, cx, () => this.close(r)), { danger: true, armed: this.armed === closeKey })))
      .when(expanded, (e) => e.children(r.children.map((p) =>
        h_flex().id(`p-${p.pid}`).pl(16).gap(8).text_size(11).text_color(t.muted)
          .child(div().flex_1().min_w(0).truncate().child(`${p.name}  (${p.pid})`))
          .child(div().child(mb(p.rss))))));
  }

  render(cx) {
    const t = theme(), sum = this.rows.reduce((s, r) => s + r.kb, 0), idle = this.idle();
    const counts = {};
    for (const r of this.rows) counts[r.name] = (counts[r.name] ?? 0) + r.kb;
    const top = Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, 3).map(([n, kb]) => `${n} ${mb(kb)}`).join(" · ");
    return v_flex().id("root").size_full().bg(t.surface).text_size(12)
      .child(v_flex().px(10).py(8).gap(4).border_b(1).border_color(t.border)
        .child(h_flex().items_center().gap(8)
          .child(div().flex_1().font_semibold().text_color(t.foreground).child(`${mb(sum)} in ${this.rows.length} terminals`))
          .when(idle.length > 0, (e) => e.child(this.button("cleanup", this.armed === "cleanup" ? `Close ${idle.length} idle?` : `Clean up ${idle.length} idle`, cx,
            (cx) => this.confirm("cleanup", cx, () => this.cleanup()), { danger: true, armed: this.armed === "cleanup" })))
          .child(this.button("refresh", "Refresh", cx, (cx) => this.refresh(cx, true))))
        .child(div().text_size(11).text_color(t.dim).truncate().child(top || "Loading…"))
        .when(Boolean(this.error), (e) => e.child(div().text_size(11).text_color(t.blocked).child(this.error))))
      .child(v_flex().id("list").flex_1().min_h(0).overflow_y_scrollbar()
        .children(this.rows.map((r) => this.row(r, cx))));
  }
}
