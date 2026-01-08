# Model Card - Arrhythmia Risk Screening Model

## Model Details

| Property | Value |
|----------|-------|
| **Model Name** | Guardian Angel Arrhythmia Risk Screener |
| **Version** | 0.1.0 (Development) |
| **Type** | Binary Classification |
| **Algorithm** | XGBoost |
| **Input** | HRV features from RR intervals |
| **Output** | Risk probability (0-1) |

## Intended Use

### Primary Use Case
- Early-stage arrhythmia risk screening in mobile health applications
- Population-level health monitoring
- Triage support for clinical follow-up

### Out-of-Scope Uses
- ❌ Clinical diagnosis of arrhythmias
- ❌ Replacement for ECG analysis
- ❌ Emergency medical decisions
- ❌ Pediatric populations (not validated)

## Training Data

| Property | Value |
|----------|-------|
| **Dataset** | MIT-BIH Arrhythmia Database |
| **Subjects** | 47 individuals |
| **Recordings** | 48 half-hour ECG segments |
| **Split Strategy** | Patient-wise stratified |

## Performance Metrics

> ⚠️ **Note**: Metrics to be populated after model training.

| Metric | Train | Validation | Test |
|--------|-------|------------|------|
| Accuracy | TBD | TBD | TBD |
| Sensitivity | TBD | TBD | TBD |
| Specificity | TBD | TBD | TBD |
| AUROC | TBD | TBD | TBD |
| F1 Score | TBD | TBD | TBD |

## Limitations

1. **Population**: Trained on limited demographic representation
2. **Conditions**: Designed for arrhythmia screening, not specific rhythm classification
3. **Input Quality**: Performance depends on RR interval quality
4. **Context**: Does not account for clinical context, medications, comorbidities

## Ethical Considerations

- Model outputs should be interpreted by healthcare professionals
- False negatives could delay necessary medical care
- False positives could cause unnecessary anxiety
- Not validated across all demographic groups

## Deployment Considerations

- Requires minimum 5 minutes of continuous RR interval data
- CPU-only inference, no GPU required
- Designed for real-time mobile deployment
- Probability threshold should be optimized for intended use case

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | TBD | Initial development version |

## Contact

For questions about this model, contact the Guardian Angel development team.

---

*This model card follows guidelines from "Model Cards for Model Reporting" (Mitchell et al., 2019)*
