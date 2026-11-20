// SSH port forward to the `workspace` VM. Type a port (3000) or local:remote (8080:3000),
// Enter starts `ssh -N -L` as a background terminal; each forward below can be opened in
// the browser or stopped. The host is fixed on purpose: forwards only go to `workspace`.
import { View, div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { exec, hc, home, terminals, theme } from "herdr";

const HOST = "workspace";
const LABEL = "herdr.forward";   // label on the terminal, value "<local>:<remote>"
const SETTLE_MS = 1500;          // a new terminal may not be listed yet
const CONNECT_MS = 6000;         // how long a forward shows "connecting"
const PORT = /^\d{1,5}$/;

// "3000" -> 3000:3000, "8080:3000" -> local 8080, remote 3000. null when invalid.
function parse(text) {
  const [local, remote = local, extra] = text.trim().split(":");
  const ok = (p) => PORT.test(p) && +p >= 1 && +p <= 65535;
  return extra === undefined && ok(local) && ok(remote) ? { local: +local, remote: +remote } : null;
}

export default class SshForward extends View {
  init(_props, cx) {
    this.forwards = [];          // [{address, spec}] live forwards
    this.known = new Map();      // terminal address -> forward spec, or null when it isn't one
    this.pending = null;         // {address, spec, at}: the forward just started
    this.error = null;
    this.input = InputState.new({ placeholder: "Port to forward, e.g. 3000 or 8080:3000" });
    this.input.on("submit", (_e, cx) => this.start(cx));
    this.input.on("change", (_e, cx) => { if (this.error) { this.error = null; cx.notify(); } });
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    this.refresh(cx);
    cx.timer.every(2000, (cx) => this.refresh(cx));
  }

  refresh(cx) {
    if (this.busy) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        const live = terminals().filter((t) => t.state === "live" && !String(t.address).includes("/"));
        // Labels never change, so each terminal is looked up once.
        await Promise.all(live.filter((t) => !this.known.has(t.address)).map(async (t) => {
          const r = await hc(["get", t.address]);
          if (r.code === 0) this.known.set(t.address, JSON.parse(r.stdout).labels?.[LABEL] ?? null);
        }));
        this.forwards = live.filter((t) => this.known.get(t.address)).map((t) => ({ address: t.address, spec: this.known.get(t.address) }));
        await this.check();
      } catch (e) {
        this.error = String(e);
      } finally {
        this.busy = false;
        cx.notify();
      }
    });
  }

  // A forward that ended right after starting (VM stopped, port taken, key locked): show why.
  async check() {
    const p = this.pending;
    if (!p) return;
    const age = Date.now() - p.at;
    if (this.forwards.some((f) => f.address === p.address)) { if (age > CONNECT_MS) this.pending = null; return; }
    if (age < SETTLE_MS) return;
    this.pending = null;
    const out = await hc(["read", p.address, "--lines", "6"]);
    await hc(["rm", p.address]);
    const why = out.stdout.trim().split("\n").filter(Boolean).slice(-2).join(" ");
    this.error = `Forward ${p.spec} failed: ${why || "ssh exited"}`;
  }

  start(cx) {
    const spec = parse(this.input.value());
    if (!spec) { this.error = "Use a port (3000) or local:remote (8080:3000)"; return cx.notify(); }
    if (this.forwards.some((f) => f.spec.split(":")[0] === String(spec.local))) {
      this.error = `Port ${spec.local} is already forwarded`;
      return cx.notify();
    }
    this.error = null;
    const label = `${spec.local}:${spec.remote}`;
    cx.spawn(async (cx) => {
      // zsh -lic: ssh's ProxyCommand needs gcloud on PATH, as in your own terminal.
      const r = await hc([
        "run", "--json", "--bg", "--no-parent", "--cwd", home(), "--label", `${LABEL}=${label}`, "--",
        "/bin/zsh", "-lic", 'exec ssh "$@"', "ssh",
        "-N", "-o", "ExitOnForwardFailure=yes", "-o", "ServerAliveInterval=30",
        "-L", `127.0.0.1:${spec.local}:localhost:${spec.remote}`, HOST,
      ]);
      if (r.code !== 0) this.error = r.stderr || r.stdout;
      else {
        const address = JSON.parse(r.stdout).address;
        this.known.set(address, label);
        this.pending = { address, spec: label, at: Date.now() };
        this.input.set_value("");
      }
      cx.notify();
      this.refresh(cx);
    });
  }

  stop(f, cx) {
    cx.spawn(async (cx) => {
      await hc(["kill", f.address]);
      await hc(["rm", f.address]);
      this.known.delete(f.address);
      this.refresh(cx);
    });
  }

  button(id, text, onClick) {
    const t = theme();
    return div().id(id).px(8).h(22).flex().items_center().rounded(4).cursor_pointer().text_size(12).text_color(t.muted)
      .hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); })
      .child(text);
  }

  row(f) {
    const t = theme(), [local, remote] = f.spec.split(":");
    const connecting = this.pending?.address === f.address && Date.now() - this.pending.at < CONNECT_MS;
    return h_flex().id(`fwd-${f.address}`).px(14).py(6).gap(8).items_center().border_b(1).border_color(t.border)
      .child(div().w(8).h(8).rounded(4).bg(connecting ? t.blocked : t.working))
      .child(v_flex().flex_1().min_w(0)
        .child(div().truncate().text_color(t.foreground).child(`localhost:${local} → ${HOST}:${remote}`))
        .child(div().text_size(11).text_color(t.dim).child(connecting ? "connecting…" : "active")))
      .child(this.button(`open-${f.address}`, "Open", () => exec("open", [`http://localhost:${local}`])))
      .child(this.button(`stop-${f.address}`, "Stop", (cx) => this.stop(f, cx)));
  }

  render() {
    const t = theme();
    return v_flex().id("root").size_full().bg(t.popover).text_size(13)
      .child(h_flex().px(14).pt(12).pb(8).items_center()
        .child(div().flex_1().font_semibold().text_color(t.foreground).child(`SSH port forward → ${HOST}`)))
      .child(div().px(12).pb(8)
        .child(div().h(32).px(10).flex().items_center().rounded(8).border_1().border_color(t.accent)
          .child(Input.new(this.input).h_full().text_size(13).text_color(t.foreground))))
      .child(div().px(14).pb(8).text_size(11).text_color(this.error ? t.blocked : t.dim)
        .child(this.error ?? "Enter starts it. Reach the VM's server at http://localhost:<port> on this Mac."))
      .child(v_flex().id("list").min_h(44).max_h(220).overflow_y_scrollbar().border_t(1).border_color(t.border)
        .children(this.forwards.map((f) => this.row(f)))
        .when(this.forwards.length === 0, (e) => e.child(div().px(14).py(10).text_color(t.dim).child("No active forwards"))));
  }
}
