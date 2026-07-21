---
title: Automated KYC & Enhanced Due Diligence
industry: BFSI
workType: Architecture
kpis:
  - { label: 'Onboarding-Zeit', value: '~80 % schneller' }
  - { label: 'Audit-Befunde', value: 'Null' }
  - { label: 'Analyst-Durchsatz', value: '~5× höher' }
tags: [KYC Automation, Regulatory AI, Entity Resolution]
order: 2
---

## Ausgangslage

Das Onboarding eines Firmenkunden bedeutete, dass Analysten hunderte Seiten an Ausweisdokumenten, Eigentümerstrukturen und Sanktionslisten manuell prüften. Der Zyklus dauerte im Schnitt drei Wochen, und uneinheitliche Risikobewertungen der regionalen Teams erzwangen häufige Nacharbeit. Daraus entstanden regulatorisches Risiko und Kundenfrust.

## Vorgehen

Aufgebaut wurde eine Multi-Agent-KYC-Pipeline, die Entitätsdaten aus eingereichten Dokumenten extrahiert, UBO-Ketten (Ultimate Beneficial Ownership) auflöst und in Echtzeit gegen globale Sanktions- und PEP-Listen abgleicht. Eine Human-in-the-Loop-Stufe prüft Grenzfälle, während risikoarme Profile automatisch freigegeben werden.

## Ergebnis

Ein Onboarding, das früher Wochen dauerte, ist heute in Tagen abgeschlossen, der Analyst-Durchsatz stieg um ein Mehrfaches, und der folgende Audit-Zyklus ergab keine regulatorischen Befunde.
