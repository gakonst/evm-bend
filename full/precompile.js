function precompile_host(input) {
  const fail = () => ({ $: "Con", head: 2, tail: [0,0,0,0,0,0,0,0].reduceRight((tail,head)=>({$:"Con",head,tail}), {$:"Nil"}) });
  try {
    const { spawnSync } = require("node:child_process");
    const path = process.env.BEND_EVM_PRECOMPILE_HOST;
    if (!path || !path.startsWith("/")) return fail();
    const bytes = [];
    for (let xs = input; xs.$ === "Con"; xs = xs.tail) {
      if (xs.head > 255) return fail();
      bytes.push(xs.head);
    }
    const result = spawnSync(path, [], { input: Buffer.from(bytes), maxBuffer: 256 * 1024 * 1024, shell: false });
    const out = result.stdout;
    if (result.error || result.status !== 0 || !out || out.length < 9 || out[0] > 2) return fail();
    let xs = {$:"Nil"};
    for (let i = out.length; i > 0; --i) xs = {$:"Con", head:out[i-1], tail:xs};
    return xs;
  } catch (_) { return fail(); }
}
