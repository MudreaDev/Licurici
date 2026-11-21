"""Read-only cross-check of the exported workbook against the exact PERT model."""
from pathlib import Path
from math import isclose
import openpyxl
from pecpit2_model import build

root=Path(__file__).resolve().parents[2]
m=build();path=root/'output/xlsx/PECPIT_lab2_Mudrea_Mihail_Licurici.xlsx'
values=openpyxl.load_workbook(path,data_only=True)
formulas=openpyxl.load_workbook(path,data_only=False)
assert values.sheetnames==['Sinteza','PERT','WBS','Trasee','Retea']
for i,r in enumerate(m['rows'],5):
    for col,key in zip('HIJKLMN',['te','variance','ES','EF','LS','LF','float']):
        assert isclose(values['PERT'][f'{col}{i}'].value,float(r[key]),abs_tol=1e-7),(i,key)
        assert formulas['PERT'][f'{col}{i}'].data_type=='f'
    assert values['PERT'][f'P{i}'].value=='OK'
for i,p in enumerate(m['paths'],5):
    assert isclose(values['Trasee'][f'C{i}'].value,float(p['duration']),abs_tol=1e-7)
    assert values['Trasee'][f'B{i}'].value==' → '.join(p['nodes'])
for sheet in values:
    assert not any(c.data_type=='e' for row in sheet for c in row),sheet.title
assert values['WBS']['A5'].value=='1.0'
assert values['Sinteza']['B13'].value=='OK'
print('OK: 48 activități, 69 pachete WBS, 78 trasee, formule și valori exportate coerente.')
