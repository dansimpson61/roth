// Main interactive script (extracted from Slim to avoid indentation issues)
(function(){
  const form = document.getElementById('controls');
  if(!form) return; // safety
  const metricsEls = Array.from(document.querySelectorAll('#metrics .metric .value'));
  const advBtn = document.getElementById('toggle-adv');
  const advSection = document.querySelector('.advanced');
  const stratSelect = document.getElementById('strategy');
  const stratValueWrapper = document.getElementById('strategy-value-wrapper');
  const baselineToggle = document.getElementById('show-baseline');

  advBtn?.addEventListener('click', () => {
    const hidden = advSection.classList.toggle('hidden');
    advBtn.textContent = (hidden ? 'Show' : 'Hide') + ' Advanced Assumptions ▾';
  });

  stratSelect?.addEventListener('change', () => {
    stratValueWrapper.style.display = (stratSelect.value === 'fixed' || stratSelect.value === 'fill_bracket') ? 'block' : 'none';
  });

  baselineToggle?.addEventListener('change', runProjection);

  function coerce(data){
    for(const k in data){ const n = parseFloat(data[k]); if(!isNaN(n)) data[k]=n; }
    return data;
  }

  function pct(a,b){ return b>0 ? (a/b*100) : 0; }
  function formatMoney(v){ if(v==null) return '--'; const k=Math.round(v/1000); return k.toLocaleString()+'k'; }

  function extractSeries(json){
    function mapYears(obj){ return obj.years.map(y=>({
      year:y.year,
      base:y.base_income||0,
      ss:y.social_security||0,
      rmd:y.rmd||0,
      conv:y.conversion||0,
      gross:y.gross_income|| (y.base_income+y.social_security+y.rmd+y.conversion),
      tax:y.federal_tax||0
    })); }
    const primary = mapYears(json.primary);
    const baseline = json.baseline ? mapYears(json.baseline) : null;
    return {primary, baseline};
  }

  function renderChart(data){
    const svg = document.getElementById('balance-chart');
    if(!svg) return;
    const w = svg.clientWidth || parseInt(svg.getAttribute('width')||800,10); const h= svg.clientHeight || 260;
    while(svg.firstChild) svg.removeChild(svg.firstChild);
    const margin = {l:52,r:12,t:6,b:40};
    const innerW = w - margin.l - margin.r; const innerH = h - margin.t - margin.b;
    const primaryPts = data.primary;
    const baselinePts = data.baseline;
    const showBaseline = baselineToggle && baselineToggle.checked && baselinePts;
    const allPts = showBaseline ? primaryPts.concat(baselinePts) : primaryPts;
  const stdDedBase = (window.__latestResult?.primary?.standard_deduction) || 0;
    // Determine actual max gross & taxable used
    const grossValues = allPts.map(d=>d.gross);
    let rawMax = Math.max(...grossValues, stdDedBase);
    const maxGrossObserved = rawMax;
    const maxTaxableObserved = Math.max(0, maxGrossObserved - stdDedBase);
    // Identify highest bracket actually entered (based on taxable income reached)
    let effectiveBracketTop = null; // stdDed + next threshold just above usage
    let usedBracketThresholds = [];
    if(window.__latestResult?.primary?.brackets){
      const br = window.__latestResult.primary.brackets;
      for(let i=0;i<br.length;i++){
        const thr = br[i][0];
        const next = br[i+1]?.[0];
        if(maxTaxableObserved >= thr) usedBracketThresholds.push(thr);
        if(next && maxTaxableObserved < next && effectiveBracketTop===null){
          effectiveBracketTop = stdDedBase + next; // limit to first bracket ceiling above observed taxable
        }
      }
    }
    if(effectiveBracketTop) rawMax = Math.max(rawMax, effectiveBracketTop); else rawMax = Math.max(rawMax, maxGrossObserved);
  if(rawMax === 0) rawMax = 1; // avoid divide by zero
  // Add modest headroom
  rawMax *= 1.06;
  // Nice scale algorithm (approx d3.nice)
  function niceDomain(max, tickCount){
    const span = max;
    const step0 = span / tickCount;
    const p10 = Math.pow(10, Math.floor(Math.log10(step0)));
    let err = step0 / p10;
    let step;
    if(err >= 7.5) step = 10 * p10;
    else if(err >= 3.5) step = 5 * p10;
    else if(err >= 1.5) step = 2 * p10;
    else step = p10;
    return Math.ceil(max / step) * step;
  }
  const maxGross = niceDomain(rawMax, 6);
    const years = primaryPts.map(d=>d.year);
    const x = (year)=> { const idx=years.indexOf(year); return margin.l + (idx/(years.length-1))*innerW; };
    const yGross = (v)=> margin.t + innerH - (v/maxGross)*innerH;
    const NS = 'http://www.w3.org/2000/svg';
    // Bands first (background)
    if(stdDedBase>0){
      const y0 = yGross(stdDedBase);
      const rect = document.createElementNS(NS,'rect'); rect.setAttribute('x', margin.l); rect.setAttribute('y', y0); rect.setAttribute('width', innerW); rect.setAttribute('height', (yGross(0)-y0)); rect.setAttribute('class','band-deduction'); svg.appendChild(rect);
      const lbl = document.createElementNS(NS,'text'); lbl.textContent='Standard Deduction'; lbl.setAttribute('x', margin.l+4); lbl.setAttribute('y', y0+10); lbl.setAttribute('class','band-label'); svg.appendChild(lbl);
    }
    if(window.__latestResult?.primary?.brackets){
      const br = window.__latestResult.primary.brackets;
      for(let i=0;i<br.length-1;i++){
        const startTaxable = br[i][0];
        const endTaxable = br[i+1][0];
        if(maxTaxableObserved < startTaxable) break; // stop drawing unused high brackets
        const yTop = yGross(stdDedBase + endTaxable);
        const yBottom = yGross(stdDedBase + startTaxable);
        const hBand = yBottom - yTop;
        if(hBand <= 2) continue;
        const rect = document.createElementNS(NS,'rect'); rect.setAttribute('x', margin.l); rect.setAttribute('y', yTop); rect.setAttribute('width', innerW); rect.setAttribute('height', hBand); rect.setAttribute('class','band-bracket'); rect.setAttribute('fill-opacity', i % 2 ? 0.28 : 0.16); svg.appendChild(rect);
        const rate = br[i][1];
        const lbl = document.createElementNS(NS,'text'); lbl.textContent=(rate*100).toFixed(0)+'%'; lbl.setAttribute('x', margin.l+4); lbl.setAttribute('y', yTop+9); lbl.setAttribute('class','band-label'); svg.appendChild(lbl);
      }
    }
    // Stacked component areas: build polygon between lower and upper cumulative curves
    function stackPath(lowerFn, upperFn){
      const top = primaryPts.map((d,i)=> (i?'L':'M')+x(d.year)+','+yGross(upperFn(d)) ).join(' ');
      const bottom = primaryPts.slice().reverse().map((d,i)=> 'L'+x(d.year)+','+yGross(lowerFn(d)) ).join(' ');
      return top + bottom + ' Z';
    }
    const basePath = stackPath(()=>0, d=>d.base);
    const ssPath = stackPath(d=>d.base, d=>d.base+d.ss);
    const rmdPath = stackPath(d=>d.base+d.ss, d=>d.base+d.ss+d.rmd);
    const convPath = stackPath(d=>d.base+d.ss+d.rmd, d=>d.base+d.ss+d.rmd+d.conv);
    const baseEl = document.createElementNS(NS,'path'); baseEl.setAttribute('d', basePath); baseEl.setAttribute('class','stack-base'); svg.appendChild(baseEl);
    const ssEl = document.createElementNS(NS,'path'); ssEl.setAttribute('d', ssPath); ssEl.setAttribute('class','stack-ss'); svg.appendChild(ssEl);
    const rmdEl = document.createElementNS(NS,'path'); rmdEl.setAttribute('d', rmdPath); rmdEl.setAttribute('class','stack-rmd'); svg.appendChild(rmdEl);
    const convEl = document.createElementNS(NS,'path'); convEl.setAttribute('d', convPath); convEl.setAttribute('class','stack-conv'); svg.appendChild(convEl);
    // Baseline line (gross)
    if(showBaseline){
      const linePath = baselinePts.map((d,i)=> (i?'L':'M')+x(d.year)+','+yGross(d.gross)).join(' ');
      const bl = document.createElementNS(NS,'path'); bl.setAttribute('d',linePath); bl.setAttribute('stroke','#666'); bl.setAttribute('stroke-dasharray','4 4'); bl.setAttribute('fill','none'); svg.appendChild(bl);
    }
  // Tax line
    const taxPath = primaryPts.map((d,i)=> (i?'L':'M')+x(d.year)+','+yGross(d.tax)).join(' ');
    const taxEl = document.createElementNS(NS,'path'); taxEl.setAttribute('d',taxPath); taxEl.setAttribute('class','tax-line'); svg.appendChild(taxEl);
    // Axes
    const axis = document.createElementNS(NS,'line'); axis.setAttribute('x1',margin.l);axis.setAttribute('x2',margin.l);axis.setAttribute('y1',margin.t);axis.setAttribute('y2',margin.t+innerH);axis.setAttribute('class','axis'); svg.appendChild(axis);
    const axisB = document.createElementNS(NS,'line'); axisB.setAttribute('x1',margin.l);axisB.setAttribute('x2',margin.l+innerW);axisB.setAttribute('y1',margin.t+innerH);axisB.setAttribute('y2',margin.t+innerH);axisB.setAttribute('class','axis'); svg.appendChild(axisB);
    // Y ticks (6)
    const steps = 6;
    for(let i=0;i<=steps;i++){
      const v = maxGross * (i/steps);
      const y = yGross(v);
      const tline = document.createElementNS(NS,'line'); tline.setAttribute('x1',margin.l-5); tline.setAttribute('x2',margin.l); tline.setAttribute('y1',y); tline.setAttribute('y2',y); tline.setAttribute('stroke','#999'); tline.setAttribute('stroke-width','0.5'); svg.appendChild(tline);
      const lbl = document.createElementNS(NS,'text'); lbl.textContent = '$'+Math.round(v/1000)+'k'; lbl.setAttribute('x', 6); lbl.setAttribute('y', y+3); lbl.setAttribute('class','series-label'); svg.appendChild(lbl);
    }
    // X-year labels every 5 years plus endpoints
    primaryPts.forEach((pt,i)=>{
      const include = (i===0 || i===primaryPts.length-1 || i % 5 === 0);
      if(!include) return;
      const tx = document.createElementNS(NS,'text'); tx.textContent=String(pt.year).slice(-2); tx.setAttribute('x', x(pt.year)-6); tx.setAttribute('y', margin.t+innerH+14); tx.setAttribute('class','series-label'); svg.appendChild(tx);
    });
    // Axis labels
    const yAxisLbl = document.createElementNS(NS,'text'); yAxisLbl.textContent='Annual $'; yAxisLbl.setAttribute('x', margin.l+8); yAxisLbl.setAttribute('y', margin.t + 12); yAxisLbl.setAttribute('class','series-label'); svg.appendChild(yAxisLbl);
    const xAxisLbl = document.createElementNS(NS,'text'); xAxisLbl.textContent='Year (YY)'; xAxisLbl.setAttribute('x', margin.l + innerW - 72); xAxisLbl.setAttribute('y', margin.t + innerH + 28); xAxisLbl.setAttribute('class','series-label'); svg.appendChild(xAxisLbl);
    // Legend (simple rebuild each time)
    const legend = document.getElementById('chart-legend');
    if(legend){
      legend.innerHTML = '';
      const items = [
        ['Base Income','stack-base'],
        ['Social Security','stack-ss'],
        ['RMD','stack-rmd'],
        ['Conversion','stack-conv'],
        ['Tax (line)','tax-line']
      ];
      items.forEach(([label, cls])=>{
        const div = document.createElement('div'); div.className='item';
        const sw = document.createElement('span'); sw.className='swatch'; if(cls==='tax-line'){ sw.style.background='linear-gradient(to right,#444,#444)'; } else { sw.classList.add(cls); }
        div.appendChild(sw);
        const txt = document.createElement('span'); txt.textContent=label; div.appendChild(txt);
        legend.appendChild(div);
      });
    }
    // Tooltip interactions
    const tooltip = document.getElementById('chart-tooltip');
    let hoverLine = null;
    function hideTooltip(){ if(tooltip) tooltip.style.display='none'; }
    function showTooltip(evt){
      if(!tooltip) return;
      const mx = evt.offsetX; // relative to svg
      if(mx < margin.l || mx > margin.l+innerW){ hideTooltip(); return; }
      const ratio = (mx - margin.l)/innerW;
      const idx = Math.min(years.length-1, Math.max(0, Math.round(ratio*(years.length-1))));
      const pt = primaryPts[idx];
      if(!pt) return;
      if(!hoverLine){ hoverLine = document.createElementNS(NS,'line'); hoverLine.setAttribute('class','hover-line'); svg.appendChild(hoverLine); }
      const xPos = x(pt.year);
      hoverLine.setAttribute('x1', xPos); hoverLine.setAttribute('x2', xPos); hoverLine.setAttribute('y1', margin.t); hoverLine.setAttribute('y2', margin.t+innerH);
      const gross = pt.base+pt.ss+pt.rmd+pt.conv;
      const taxable = Math.max(0, gross - stdDedBase);
      let bracketRate = null;
      if(window.__latestResult?.primary?.brackets){
        const br = window.__latestResult.primary.brackets;
        for(let i=0;i<br.length;i++){
          const next = br[i+1]?.[0] ?? 1e15;
            if(taxable >= br[i][0] && taxable < next){ bracketRate = br[i][1]; break; }
        }
      }
  const fmt = v=> '$'+Math.round(v/1000)+'k';
  tooltip.innerHTML = `<h4>${pt.year}</h4><table>
        <tr><td>Gross</td><td class="val">${fmt(gross)}</td></tr>
        <tr><td>Base</td><td class="val">${fmt(pt.base)}</td></tr>
        <tr><td>SS</td><td class="val">${fmt(pt.ss)}</td></tr>
        <tr><td>RMD</td><td class="val">${fmt(pt.rmd)}</td></tr>
        <tr><td>Conv</td><td class="val">${fmt(pt.conv)}</td></tr>
        <tr><td>Tax</td><td class="val">${fmt(pt.tax)}</td></tr>
        <tr><td colspan="2">${bracketRate? (bracketRate*100).toFixed(0)+'% bracket':''}</td></tr>
      </table>`;
  // Show to measure
  tooltip.style.display='block';
  tooltip.style.visibility='hidden';
  const ttW = tooltip.offsetWidth || 160;
  const ttH = tooltip.offsetHeight || 110;
  const cursorX = mx;
  const cursorY = evt.offsetY;
  // Anchor to vertical guide (xPos) for stability
  let left = xPos + 6;
  if(left + ttW > margin.l + innerW) left = xPos - ttW - 6;
  if(left < 2) left = 2;
  let top = cursorY + 6;
  if(top + ttH > margin.t + innerH) top = cursorY - ttH - 6;
  if(top < 2) top = 2;
  const svgRect = svg.getBoundingClientRect();
  tooltip.style.left = (svgRect.left + window.scrollX + left) + 'px';
  tooltip.style.top = (svgRect.top + window.scrollY + top) + 'px';
  tooltip.style.visibility='visible';
    }
    svg.addEventListener('mousemove', showTooltip);
    svg.addEventListener('mouseleave', hideTooltip);
  }

  async function runProjection(){
    const data = Object.fromEntries(new FormData(form).entries());
    coerce(data);
    const res = await fetch('/run', {method:'POST', body: JSON.stringify(data)});
    if(!res.ok) return;
  const json = await res.json();
  window.__latestResult = json; // stash for chart labels
    const outputEl = document.getElementById('output');
    if(outputEl) outputEl.textContent = JSON.stringify(json, null, 2);
    if(json.primary){
      const p=json.primary.totals; const bp=json.baseline ? json.baseline.totals : null;
      const pRothPct = pct(p.ending_roth, p.ending_roth + p.ending_trad);
      metricsEls[0].textContent = formatMoney(p.taxes_paid);
      if(bp){
        metricsEls[1].textContent = formatMoney(bp.taxes_paid);
        metricsEls[2].textContent = formatMoney(p.taxes_paid - bp.taxes_paid);
        const bRothPct = pct(bp.ending_roth, bp.ending_roth + bp.ending_trad);
        metricsEls[3].textContent = pRothPct.toFixed(1)+'%';
        metricsEls[4].textContent = bRothPct.toFixed(1)+'%';
        metricsEls[5].textContent = (pRothPct - bRothPct).toFixed(1)+'%';
      } else {
        metricsEls[1].textContent = '--'; metricsEls[2].textContent='--'; metricsEls[3].textContent=pRothPct.toFixed(1)+'%'; metricsEls[4].textContent='--'; metricsEls[5].textContent='--';
      }
      renderChart(extractSeries(json));
    }
  }

  let debounceTimer; form.addEventListener('input', () => { clearTimeout(debounceTimer); debounceTimer=setTimeout(runProjection, 450); });
  form.addEventListener('submit', (e)=>{ e.preventDefault(); runProjection(); });
  // Raw JSON toggle
  const jsonToggle = document.getElementById('toggle-json');
  const outputPre = document.getElementById('output');
  jsonToggle?.addEventListener('click', ()=>{
    const hidden = outputPre.classList.toggle('hidden');
    jsonToggle.textContent = (hidden ? 'Show' : 'Hide') + ' Raw JSON ▾';
  });
  runProjection();
})();
