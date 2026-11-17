// Side panel tab strip (Files | Changes) for the `dev` layout.
// Also keeps one yazi terminal running for the Files tab: it starts yazi in the
// active space's folder, points the layout's `files` block at it, and moves yazi
// (`ya emit-to <id> cd`) when the active space changes. Local spaces only.
import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { run, layout, spaces, terminals, hc, exec, theme, appHome, home } from "herdr";

const STACK = "side-body";
const BLOCK = "side-files";
const TABS = [{ id: "side-files", label: "Files" }, { id: "side-changes", label: "Changes" }, { id: "side-processes", label: "Processes" }];

function find(node, id) {
  if (!node || typeof node !== "object") return null;
  if (node.id === id) return node;
  for (const child of node.children ?? []) {
    const hit = find(child, id);
    if (hit) return hit;
  }
  return null;
}

export default class SideTabs extends View {
  init(_props, cx) {
    const saved = JSON.parse(localStorage.getItem("yazi") ?? "null");
    this.addr = saved?.addr ?? null;
    this.client = saved?.client ?? null;
    this.folder = saved?.folder ?? null;
    this.busy = false;
    this.tick(cx);
    // Only reads live data each second; exec runs only when something changed.
    cx.timer.every(1000, (cx) => this.tick(cx));
  }

  save() {
    localStorage.setItem("yazi", JSON.stringify({ addr: this.addr, client: this.client, folder: this.folder }));
  }

  tick(cx) {
    if (this.busy) return;
    const space = spaces().find((s) => s.active);
    if (!space || space.machine) return; // remote spaces: keep the local yazi as it is
    const folder = space.folder || home();
    const alive = this.addr && terminals().some((t) => t.address === this.addr && t.state === "live");
    if (!alive) return this.start(folder, cx);
    this.point();
    if (folder !== this.folder) this.cd(folder, cx);
  }

  start(folder, cx) {
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        const dir = `${appHome()}/mods/side-tabs`;
        const client = String(Date.now());
        const r = await hc([
          "run", "--json", "--bg", "--no-parent", "--rm", "--label", "herdr.panel=yazi", "--cwd", folder, "--",
          "env", `YAZI_CONFIG_HOME=${dir}/yazi`, `HERDR_PANEL_DIR=${dir}`, "yazi", "--client-id", client,
        ]);
        if (r.code !== 0) throw new Error(r.stderr || r.stdout);
        this.addr = JSON.parse(r.stdout).address;
        this.client = client;
        this.folder = folder;
        this.save();
        this.point();
      } catch (e) {
        console.log(`side-tabs: yazi did not start: ${e}`);
      } finally {
        this.busy = false;
        cx.notify();
      }
    });
  }

  cd(folder, cx) {
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        const r = await exec("ya", ["emit-to", this.client, "cd", folder]);
        if (r.code === 0) { this.folder = folder; this.save(); }
      } finally {
        this.busy = false;
        cx.notify();
      }
    });
  }

  // Shows the yazi terminal in the layout's files block. Herdr drops a terminal
  // block from the layout when its program exits, so put it back first in the stack.
  point() {
    const root = layout();
    if (find(root, BLOCK)?.content?.terminal === this.addr) return;
    const next = JSON.parse(JSON.stringify(root)), content = { terminal: this.addr };
    const block = find(next, BLOCK), body = find(next, STACK);
    if (block) block.content = content;
    else if (body) body.children = [{ id: BLOCK, type: "block", content }, ...(body.children ?? [])];
    else return;
    run("layout.set", { layout: next });
  }

  async close() {
    if (this.addr) await exec("hc", ["kill", this.addr]);
  }

  render() {
    const t = theme(), active = find(layout(), STACK)?.active ?? TABS[0].id;
    return h_flex().id("root").size_full().px(8).gap(4).items_center().bg(t.chrome).border_b(1).border_color(t.border).text_size(12)
      .children(TABS.map((tab) => {
        const on = active === tab.id;
        return h_flex().id(`side-${tab.id}`).h(26).px(10).items_center().rounded(6).cursor_pointer()
          .text_color(on ? t.foreground : t.muted)
          .when(on, (e) => e.bg(t.selected).font_semibold())
          .hover((s) => s.bg(t.hover))
          .on_click(() => run("layout.select", { stack: STACK, child: tab.id }))
          .child(div().child(tab.label));
      }));
  }
}
