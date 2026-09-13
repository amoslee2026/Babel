# Specification Review Dimensions

## 1. Completeness
- All functional requirements specified
- All interfaces defined (signals, protocols, timing)
- All operating modes covered (normal, debug, test, low-power)
- Error conditions and recovery specified

## 2. Consistency
- No contradictions between documents
- Terminology used consistently
- Cross-references are valid
- Parameter ranges don't conflict

## 3. Ambiguity
- Requirements are unambiguous and measurable
- "Shall" vs "should" used correctly
- No "TBD" or "TODO" in critical sections
- Numeric values have tolerances

## 4. Testability
- Every requirement can be verified (simulation, formal, or analysis)
- Acceptance criteria are quantified
- Test scenarios can be derived
- Coverage metrics are defined

## 5. Traceability
- Requirements have unique IDs
- REQ_IDs flow from PRD -> ARCH -> MAS
- No orphan requirements
- spec_hash covers all documents
