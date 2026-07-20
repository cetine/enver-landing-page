---
title: Adaptive Fraud Detection Network
industry: BFSI
workType: Engineering
kpis:
  - { label: 'False Positives', value: '~75 % weniger' }
  - { label: 'Neue Betrugsmuster', value: '>3× mehr erkannt' }
  - { label: 'Untersuchungszeit', value: '~70 % kürzer' }
tags: [LLM, Anomaly Detection, Streaming]
order: 1
---

## Ausgangslage

Die regelbasierte Fraud-Engine markierte überwiegend legitime Transaktionen — die Ermittler verbrachten ihre Tage mit dem Triagieren von Rauschen, während neuartige Betrugsmuster durchrutschten. Die Verluste stiegen trotz wachsendem Team.

## Vorgehen

Statische Regeln wurden durch ein adaptives Erkennungsnetz ersetzt: Streaming-Feature-Pipeline, Anomalie-Modelle mit LLM-gestützter Fallzusammenfassung und eine Feedback-Schleife von Ermittler-Entscheidungen zurück in die Modelle.

## Ergebnis

Ermittler starten heute mit priorisierten, vorzusammengefassten Fällen statt roher Alerts. False Positives sanken um eine Größenordnung, deutlich mehr neuartiger Betrug wird erkannt, die Triagezeit pro Fall bricht ein.
