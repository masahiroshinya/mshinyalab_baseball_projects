const fs = require('fs');
const {mathjax} = require('mathjax-full/js/mathjax.js');
const {TeX} = require('mathjax-full/js/input/tex.js');
const {SVG} = require('mathjax-full/js/output/svg.js');
const {liteAdaptor} = require('mathjax-full/js/adaptors/liteAdaptor.js');
const {RegisterHTMLHandler} = require('mathjax-full/js/handlers/html.js');
const {AllPackages} = require('mathjax-full/js/input/tex/AllPackages.js');
const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);
const doc = mathjax.document('', {InputJax: new TeX({packages: AllPackages}), OutputJax: new SVG({fontCache: 'none'})});
const eqs = {
  '01_Fx': String.raw`F_x(t)=F_{1,x}(t)+F_{2,x}(t)`,
  '02_Fbase': String.raw`F_{\mathrm{base}}=\mathrm{median}\left(F_x(t)\right),\quad t_{\mathrm{cue}}-0.5\,\mathrm{s}\le t<t_{\mathrm{cue}}`,
  '03_Fthr': String.raw`F_{\mathrm{thr}}=F_{\mathrm{base}}+0.20\times\left(\max_{t_{\mathrm{cue}}\le t\le t_{\mathrm{FC}}}F_x(t)-F_{\mathrm{base}}\right)`,
  '04_tonset': String.raw`t_{\mathrm{onset}}=\min\left\{t>t_{\mathrm{cue}}:F_x(\tau)>F_{\mathrm{thr}},\ \forall\tau\in\left[t,t+20\,\mathrm{ms}\right]\right\}`,
  '05_RT': String.raw`RT=t_{\mathrm{onset}}-t_{\mathrm{cue}}`,
  'speed_01_vi': String.raw`v_i(t)=\frac{p_i(t+\Delta t)-p_i(t-\Delta t)}{2\,\Delta t},\quad i=x,y,z`,
  'speed_02_v': String.raw`v(t)=\sqrt{v_x(t)^2+v_y(t)^2+v_z(t)^2}`,
  'speed_03_vpeak': String.raw`v_{\mathrm{peak}}=\max\,v(t)`,
  'mt_01_tpeak': String.raw`t_{\mathrm{peak}}=\mathop{\arg\max}\,v(t)`,
  'mt_02_MT': String.raw`MT=t_{\mathrm{peak}}-t_{\mathrm{onset}}`,
  'fz_01_peak': String.raw`\mathrm{Peak}\,F_z=\frac{\max\,F_z(t)}{BW}`,
};
const out = process.argv[2];
fs.mkdirSync(out, {recursive: true});
for (const [name, tex] of Object.entries(eqs)) {
  const node = doc.convert(tex, {display: true});
  let svg = adaptor.innerHTML(node);
  svg = svg.replace('<svg ', '<svg xmlns:xlink="http://www.w3.org/1999/xlink" ').replace(/currentColor/g, '#000000');
  // Affinity は ex 単位を読めないので、24 pt 相当の pt に直す
  const vb = svg.match(/viewBox="[-\d.]+ [-\d.]+ ([\d.]+) ([\d.]+)"/);
  const k = 24 / 1000;
  svg = svg.replace(/width="[\d.]+ex"/, `width="${(vb[1]*k).toFixed(1)}pt"`)
           .replace(/height="[\d.]+ex"/, `height="${(vb[2]*k).toFixed(1)}pt"`)
           .replace(/ style="vertical-align: [-\d.]+ex;"/, '');
  const prefix = /^(speed|mt|fz)_/.test(name) ? '' : 'onset_';
  fs.writeFileSync(`${out}/${prefix}${name}.svg`, '<?xml version="1.0" encoding="UTF-8"?>\n' + svg);
  console.log(name, svg.length);
}
