---
title: Adaptive Fraud Detection Network
industry: BFSI
workType: Engineering
kpis:
  - { label: 'False positives', value: '~75 % fewer' }
  - { label: 'Novel fraud caught', value: '>3× more' }
  - { label: 'Investigation time', value: '~70 % less' }
tags: [LLM, Anomaly Detection, Streaming]
order: 1
---

## Challenge

The legacy rule-based fraud engine flagged overwhelmingly legitimate transactions — investigators spent their days triaging noise while novel fraud patterns slipped through. Losses were rising despite a growing team.

## Approach

Replaced static rules with an adaptive detection network: streaming feature pipeline, anomaly models with LLM-assisted case summarization, and a feedback loop from investigator decisions back into the models.

## Impact

Investigators now start from ranked, pre-summarized cases instead of raw alerts. False positives dropped by an order of magnitude class, materially more novel fraud is caught, and triage time per case collapsed.
