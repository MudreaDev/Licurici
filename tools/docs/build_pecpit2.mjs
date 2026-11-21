import fs from 'node:fs/promises';
import { Workbook, SpreadsheetFile } from '@oai/artifact-tool';
const root=process.cwd(), tmp=root+'/tmp/pecpit2';
const m=JSON.parse(await fs.readFile(tmp+'/model.json','utf8'));
const wb=Workbook.create();
const sheets=Object.fromEntries(['Sinteza','PERT','WBS','Trasee','Retea'].map(n=>[n,wb.worksheets.add(n)]));
const idx=Object.fromEntries(m.rows.map((r,i)=>[r.code,i+5]));
function cell(s,a,v,formula=false){s.getRange(a)[formula?'formulas':'values']=[[v]];}
function base(s,title,heads,widths,count){
 const end=String.fromCharCode(64+heads.length);const all=s.getRange(`A1:${end}${count+4}`);
 all.format.font={name:'Arial',size:10,color:'#172B46'};all.format.verticalAlignment='center';all.format.wrapText=true;
 s.mergeCells(`A1:${end}1`);s.mergeCells(`A2:${end}2`);s.showGridLines=false;cell(s,'A1',title);s.getRange('A1').format.font={name:'Arial',size:13,bold:true,color:'#1F3864'};
 s.getRange(`A4:${end}4`).values=[heads];s.getRange(`A4:${end}4`).format.fill='#1F3864';s.getRange(`A4:${end}4`).format.font={name:'Arial',size:10,bold:true,color:'#FFFFFF'};
 s.getRange(`A4:${end}${count+4}`).format.borders={preset:'all',style:'thin',color:'#D4DCE5'};
 widths.forEach((w,i)=>s.getRange(`${String.fromCharCode(65+i)}1:${String.fromCharCode(65+i)}${count+4}`).format.columnWidth=w);
 s.getRange(`A5:${end}${count+4}`).format.rowHeight=44;s.getRange(`A4:${end}4`).format.rowHeight=30;s.freezePanes.freezeRows(4);
}
let s=sheets.PERT;
base(s,'PERT — Licurici | Mudrea Mihail, TI-233',['PERT','WBS','Activitate','Predecesori','O (h)','M (h)','P (h)','te (h)','Var. (h²)','ES','EF','LS','LF','RT','Critică','Verificare'],[9,22,48,23,10,10,10,12,12,12,12,12,12,12,10,12],48);
cell(s,'A2','Editați numai E:G. Structura dependențelor este fixă; ore de lucru, fără calendar.');s.getRange('A2:P2').format.rowHeight=32;
s.getRange('A5:G52').values=m.rows.map(r=>[r.code,r.wbs.join(', '),r.name,r.pred.join(', ')||'—',r.O,r.M,r.P]);
for(const r of m.rows){let n=idx[r.code];
 const f=[`=IF(P${n}="OK",(E${n}+4*F${n}+G${n})/6,NA())`,`=((G${n}-E${n})/6)^2`,r.pred.length?`=MAX(${r.pred.map(p=>'K'+idx[p]).join(',')})`:'=0',`=J${n}+H${n}`,`=M${n}-H${n}`,r.succ.length?`=MIN(${r.succ.map(c=>'L'+idx[c]).join(',')})`:'=MAX(K5:K52)',`=L${n}-J${n}`,`=IF(ABS(N${n})<0.000001,"DA","NU")`,`=IF(AND(COUNT(E${n}:G${n})=3,E${n}>0,E${n}<=F${n},F${n}<=G${n}),"OK","EROARE")`];
 s.getRange(`H${n}:P${n}`).formulas=[f];
}
s.getRange('E5:G52').format.fill='#EAF3FF';s.getRange('E5:G52').format.font.color='#0000CC';s.getRange('H5:N52').setNumberFormat('0.00');
s.getRange('A5:D52').conditionalFormats.add('Custom',{formula:'$O5="DA"',format:{fill:'#F4CFF4',font:{bold:true}}});
s.dataValidations.add({range:'E5:G52',rule:{type:'decimal',operator:'greaterThan',formula1:0}});
s=sheets.Trasee;base(s,'Toate cele 78 de trasee Start–Final',['ID','Succesiunea completă','Durata (h)','Activități','Critic'],[9,145,16,14,10],78);
cell(s,'A2','Ordinea inițială este fixă. Duratele și marcajul critic se recalculează.');
for(let i=0;i<m.paths.length;i++){let p=m.paths[i],n=i+5;s.getRange(`A${n}:B${n}`).values=[[p.id,p.nodes.join(' → ')]];cell(s,`C${n}`,`=SUM(${p.nodes.map(c=>`PERT!H${idx[c]}`).join(',')})`,true);cell(s,`D${n}`,p.nodes.length);cell(s,`E${n}`,`=IF(ABS(C${n}-MAX(PERT!K5:K52))<0.000001,"DA","NU")`,true);}
s.getRange('C5:C82').setNumberFormat('0.00');s.getRange('A5:E82').format.rowHeight=58;
s.getRange('A5:E82').conditionalFormats.add('Custom',{formula:'$E5="DA"',format:{fill:'#F4CFF4',font:{bold:true}}});
s=sheets.WBS;base(s,'Acoperirea integrală a WBS — laboratorul 1',['Cod WBS','Nivel','Element WBS','Activități PERT'],[14,9,85,26],m.wbs.length);
cell(s,'A2','Numai pachetele terminale sunt estimate; 1.9.2 este împărțit între P09, P17 și P42.');
s.getRange(`A5:D${m.wbs.length+4}`).values=m.wbs.map(r=>[r.code,r.code==='1.0'?0:r.code.split('.').length-1,r.name,m.rows.filter(p=>p.wbs.includes(r.code)).map(p=>p.code).join(', ')||'Nod-părinte; neestimat']);
s=sheets.Retea;base(s,'Rețeaua: dependențe și fundamentarea estimărilor',['Cod','Activitate','Predecesori','Succesori','te (h)','Baza estimării','Logica dependențelor'],[9,45,22,22,12,80,80],48);
cell(s,'A2','Rețea final–început. Figurile din raport corespund estimării inițiale.');
for(const r of m.rows){let n=idx[r.code];s.getRange(`A${n}:G${n}`).values=[[r.code,r.name,r.pred.join(', ')||'START',r.succ.join(', ')||'FINAL',null,r.basis,r.logic]];cell(s,`E${n}`,`=PERT!H${n}`,true);}
s.getRange('A5:G52').format.rowHeight=76;s.getRange('E5:E52').setNumberFormat('0.00');
s=sheets.Sinteza;base(s,'Laboratorul 2 — PERT | Licurici',['Indicator','Valoare','Interpretare'],[46,22,100],15);
const summaries=[
 ['Activități PERT','=COUNTA(PERT!A5:A52)','48 de activități care acoperă 69 de pachete terminale.'],
 ['Trasee complete','=COUNTA(Trasee!A5:A82)','Enumerare integrală, fără cicluri, de la P01 la P48.'],
 ['Trasee critice','=COUNTIF(Trasee!E5:E82,"DA")','Se poate modifica după editarea estimărilor.'],
 ['Durata proiectului (ore)','=MAX(PERT!K5:K52)','Durata pe dependențe, cu paralelism și fără nivelarea resurselor.'],
 ['Efort total (ore-om)','=SUM(PERT!H5:H52)','Încărcarea pentru un singur executant pe fiecare activitate.'],
 ['Activități critice','=COUNTIF(PERT!O5:O52,"DA")','Rezerva totală este zero; se evidențiază în foaia PERT.'],
 ['Estimări valide','=COUNTIF(PERT!P5:P52,"OK")','Trebuie să coincidă cu numărul activităților.'],
 ['Control durată trasee','=MAX(Trasee!C5:C82)-MAX(PERT!K5:K52)','Trebuie să fie 0.'],
 ['Control estimări','=IF(COUNTIF(PERT!P5:P52,"OK")=COUNTA(PERT!A5:A52),"OK","EROARE")','Orice valoare invalidă trebuie corectată înainte de interpretare.'],
 ['Ore pe zi — exemplu',8,'Ipoteză ilustrativă, nu disponibilitate confirmată.'],
 ['Zile echivalente solo','=B9/B14','Efort total / ore pe zi; nu este calendar de predare.'],
 ['Intrări editabile','PERT!E5:G52','O, M, P în ore, cu 0 < O ≤ M ≤ P; celule albastre.'],
 ['Structură','Fixă','Editarea textului predecesorilor nu reconstruiește formulele.'],
 ['Sursa estimărilor','Ipoteze ale autorului','WBS Lab. 1 și README Licurici; nu sunt pontaje sau valori din exemplul Iuliei.'],
 ['Coordonare','Cojocaru Svetlana','Mudrea Mihail, TI-233 · 2026. Asistentul AI pentru adulți este inclus.']];
summaries.forEach((r,i)=>{let n=i+5;cell(s,'A'+n,r[0]);cell(s,'B'+n,r[1],String(r[1]).startsWith('='));cell(s,'C'+n,r[2]);});
s.getRange('B8:B9').setNumberFormat('0.00');s.getRange('B15').setNumberFormat('0.00');
wb.recalculate();
function near(a,b,msg){if(Math.abs(Number(a)-b)>1e-7)throw Error(msg+': '+a+' != '+b);}
near(sheets.Sinteza.getRange('B8').values[0][0],m.stats.duration,'Duration');
near(sheets.Sinteza.getRange('B9').values[0][0],m.stats.effort,'Effort');
for(const r of m.rows){const vals=sheets.PERT.getRange(`H${idx[r.code]}:N${idx[r.code]}`).values[0];['te','variance','ES','EF','LS','LF','float'].forEach((k,j)=>near(vals[j],r[k],r.code+' '+k));}
for(let i=0;i<m.paths.length;i++)near(sheets.Trasee.getRange('C'+(i+5)).values[0][0],m.paths[i].duration,'Path '+i);
const original=m.rows[0].O;cell(sheets.PERT,'E5',original+6);wb.recalculate();near(sheets.Sinteza.getRange('B8').values[0][0],m.stats.duration+1,'Perturbation critical');cell(sheets.PERT,'E5',original);
cell(sheets.PERT,'E5',1000);wb.recalculate();if(sheets.PERT.getRange('P5').values[0][0]!=='EROARE')throw Error('Invalid input not detected');cell(sheets.PERT,'E5',original);wb.recalculate();
console.log((await wb.inspect({kind:'region',sheetId:'Sinteza',range:'A5:C15',maxChars:3500,tableMaxRows:11,tableMaxCols:3})).ndjson);
for(const [name,range] of Object.entries({Sinteza:'A1:C19',PERT:'A1:P12',WBS:'A1:D15',Trasee:'A1:E9',Retea:'A1:G9'})){
 const png=await wb.render({sheetName:name,range,scale:1,format:'png'});await fs.writeFile(tmp+'/excel-'+name+'.png',new Uint8Array(await png.arrayBuffer()));
}
for(const sh of Object.values(sheets))for(const row of sh.getUsedRange().values)for(const value of row)if(typeof value==='string'&&/^#(REF!|DIV\/0!|VALUE!|N\/A|NAME\?|NUM!|SPILL!|CALC!)/.test(value))throw Error('Formula error '+value);
await fs.mkdir(root+'/output/xlsx',{recursive:true});await (await SpreadsheetFile.exportXlsx(wb)).save(root+'/output/xlsx/PECPIT_lab2_Mudrea_Mihail_Licurici.xlsx');
console.log('Verified 48 CPM rows, 78 paths, critical input perturbation, invalid input, restored baseline.');
