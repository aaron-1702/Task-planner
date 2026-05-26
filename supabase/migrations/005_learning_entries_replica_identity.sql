-- Migration 005: Enable REPLICA IDENTITY FULL for learning_entries

ALTER TABLE learning_entries REPLICA IDENTITY FULL;
