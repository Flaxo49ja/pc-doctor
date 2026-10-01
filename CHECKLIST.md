# Buyer's checklist — before, during, after the inspection

## Ask in chat BEFORE meeting (any hesitation = red flag)

1. Why are you selling?
2. How old is it, and how many hours a day did you use it?
3. Battery: how long does it last now on a full charge?
4. Any repairs? Screen, keyboard, board replaced?
5. Any password (BIOS/supervisor, Windows account)? Remove them before we meet.
6. Can I boot my own USB stick on it? (If no → do not bother meeting.)

## Red flags

- Refuses USB boot, or insists "just look at screenshots"
- Wants a deposit before you test
- Rushes you ("I have another buyer waiting")
- Price far below market "because I need money urgently"
- Different serial number in photos than on the machine
- Selling "for a friend" and cannot answer basic questions

## What to bring

- USB stick #1: pc-doctor live ISO (Ventoy + ISO + MemTest86+)
- USB stick #2: blank, for testing every port and copying the report
- Power strip + your own charger (test charging with a known-good adapter)
- Small Phillips screwdriver (bottom panel inspection)
- Phone: photograph every test screen
- Printed copy of this checklist

## At the meeting — order of operations

1. Meet in a public place (mall, café with power)
2. Machine must boot from OFF in front of you (watch for slow/failed boots)
3. Boot your USB → run pc-doctor.sh → enter the seller's claimed specs
4. Photograph the claims-vs-reality table and the verdict screen
5. Run the slow checks (surface scan) only if the fast checks pass
6. Check BIOS: power-on hours, supervisor password, anti-theft flags
7. Only then discuss money using the price-deduction sheet
8. Pay only after: your USB booted, report saved, no FAIL rows

## After buying (first 48h)

- Run MemTest86+ overnight (2 passes minimum)
- Full badblocks read scan of the disk
- Reinstall the OS fresh — never trust the previous owner's data
- Update BIOS/firmware from the manufacturer only
