# Procedura în caz de incident de securitate a datelor

> Ciornă (Legea 195/2024; GDPR art. 33–34). Vezi [README](README.md).

## Cine
- **Responsabil incident:** […nume, telefon…] — decide și coordonează.
- **Tehnic:** […] — investighează, oprește scurgerea, restaurează.
- Oricine observă ceva suspect anunță imediat responsabilul (nu „repară” singur, nu șterge urme).

## Pașii (ceasul de 72 de ore pornește când aflăm)
1. **Detectare (ora 0).** Se notează în registrul de incidente: ce s-a observat, când, de cine.
2. **Izolare (primele ore).** Revocarea cheilor/tokenurilor compromise (`JWT_SECRET` nou → toate
   sesiunile expiră; ștergerea refresh tokenurilor din Redis; rotirea parolelor de infrastructură;
   `ANTHROPIC_API_KEY` nouă dacă e cazul), oprirea serviciului afectat, păstrarea jurnalelor.
3. **Evaluare (≤ 24 h).** Ce date (categorii, câte persoane, copii?), confidențialitate / integritate /
   disponibilitate, cât de probabil e un prejudiciu. Datele copiilor ridică automat gravitatea.
4. **Notificarea autorității (≤ 72 h)** — **CNPDCP** (și ANSPDCP pentru utilizatorii din România), dacă
   incidentul poate afecta drepturile persoanelor. Dacă nu avem toate informațiile, notificăm parțial și
   completăm.
5. **Notificarea părinților (fără întârziere nejustificată)** dacă riscul e ridicat: ce s-a întâmplat, ce
   date, ce am făcut, ce pot face ei (de ex. schimbarea parolei), contactul nostru. Limbaj simplu.
6. **Remediere și lecții** (≤ 2 săptămâni): cauza, măsuri, test care previne repetarea, actualizarea
   DPIA.

## Registrul incidentelor
Fiecare incident (chiar și cele nenotificate): data, descrierea, datele afectate, evaluarea riscului,
decizia de notificare și motivul, măsurile. Păstrat […locul…], cel puțin 5 ani.

## Exemple și gravitate orientativă
| Situație | Notificăm autoritatea? | Notificăm părinții? |
|---|---|---|
| Bază de date expusă public, cu sesiuni ale copiilor | Da | Da |
| Parolă de administrator scursă, fără dovezi de acces | Da (risc posibil) | De evaluat |
| E-mail trimis greșit unui singur părinte, cu rezumatul altui copil | Da | Da (părintele afectat) |
| Server indisponibil o zi, fără pierdere de date | De regulă nu (doar registru) | Nu |
