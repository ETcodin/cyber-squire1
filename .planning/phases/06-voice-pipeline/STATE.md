# Phase 06: Voice Pipeline - State Tracker

## Overview
Enable voice note transcription and processing through faster-whisper integration.

## Progress: 0/4 Plans Completed (0%)

---

## 06-01: faster-whisper Docker Container ❌ NOT STARTED
**Status**: Pending
**Dependencies**: None
**Blocker**: None

### Tasks
- [ ] Add faster-whisper service to docker-compose.yaml
- [ ] Deploy container to EC2
- [ ] Verify health check endpoint
- [ ] Test transcription API with sample audio

### Artifacts
- [ ] Updated docker-compose.yaml
- [ ] Container running on EC2
- [ ] API health check passing

---

## 06-02: Voice Detection & Download ❌ NOT STARTED
**Status**: Pending
**Dependencies**: 06-01
**Blocker**: None

### Tasks
- [ ] Create voice_handler.json workflow
- [ ] Add voice detection to supervisor workflow
- [ ] Implement Telegram file download
- [ ] Add initial status message ("Transcribing...")

### Artifacts
- [ ] voice_handler.json workflow
- [ ] Updated supervisor workflow
- [ ] Status message appears within 2 seconds

---

## 06-03: Transcription Integration ❌ NOT STARTED
**Status**: Pending
**Dependencies**: 06-02
**Blocker**: None

### Tasks
- [ ] Add format conversion check
- [ ] Integrate faster-whisper API call
- [ ] Echo transcription to user
- [ ] Route transcription to AI pipeline

### Artifacts
- [ ] Transcription API integration
- [ ] Echo message workflow
- [ ] AI pipeline routing

---

## 06-04: Error Handling & Edge Cases ❌ NOT STARTED
**Status**: Pending
**Dependencies**: 06-03
**Blocker**: None

### Tasks
- [ ] Add duration validation (max 60s)
- [ ] Add transcription error handling
- [ ] Handle empty transcriptions
- [ ] Add progress indicators for long notes
- [ ] Add logging to database

### Artifacts
- [ ] Error handling workflow nodes
- [ ] Database logging implementation
- [ ] Edge case test results

---

## SQL Schema Requirements

### voice_transcriptions table
```sql
CREATE TABLE IF NOT EXISTS voice_transcriptions (
    id SERIAL PRIMARY KEY,
    message_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    duration INTEGER NOT NULL,
    transcription_time INTEGER,
    transcription_length INTEGER,
    transcription_text TEXT,
    success BOOLEAN NOT NULL DEFAULT true,
    error_message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(message_id)
);

CREATE INDEX idx_voice_user_timestamp ON voice_transcriptions(user_id, timestamp DESC);
```

---

## Success Criteria (from ROADMAP.md)

1. **SC-6.1**: Voice note (any duration <60s) triggers transcription pipeline
2. **SC-6.2**: User sees "Transcribing..." within 2 seconds of sending
3. **SC-6.3**: Transcription echoed: "You said: [transcription]"
4. **SC-6.4**: Transcribed text routes correctly (same as typed text)
5. **SC-6.5**: faster-whisper container healthy in docker-compose

---

## Testing Checklist

### Basic Functionality
- [ ] 5-second voice note transcribes correctly
- [ ] 30-second voice note transcribes correctly
- [ ] 55-second voice note transcribes correctly
- [ ] Status message appears within 2 seconds
- [ ] Echo message shows transcription

### Edge Cases
- [ ] 61-second voice note rejected with message
- [ ] Silent voice note detected as empty
- [ ] Background noise only handled gracefully
- [ ] Whisper container down triggers error message
- [ ] Network timeout handled gracefully

### Integration
- [ ] Transcription routes through AI pipeline
- [ ] Voice command executes correctly
- [ ] Database logs all transcriptions
- [ ] Error logs contain useful debug info

---

## Notes

- **Model choice**: Using "base" model for balance of speed vs accuracy
- **Language**: Hardcoded to English (can expand later)
- **Format**: Telegram always sends .oga (Ogg/Opus), no conversion needed
- **Container**: Using CPU version to avoid GPU conflicts with Ollama
- **Network**: faster-whisper on Docker network, no external exposure

---

Last Updated: 2026-02-04 by Claude Sonnet 4.5
