-- Création de la base de données si elle n'existe pas
-- (déjà créée par les variables d'environnement PostgreSQL)

-- Extension pour les UUID (si besoin)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table unifiée pour les datasets avec statut et quality_score
CREATE TABLE IF NOT EXISTS datasets (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    status VARCHAR(20) DEFAULT 'raw', -- Enum: raw, processing, cleaned, premium, published, rejected
    quality_score DECIMAL(3,2), -- Score 0.00-10.00
    raw_data JSONB,
    cleaned_data JSONB,
    headers TEXT[] NOT NULL,
    row_count INTEGER,
    file_size BIGINT,
    file_hash VARCHAR(64) UNIQUE, -- Hash SHA256 pour éviter les doublons
    metadata JSONB, -- Informations supplémentaires (mime_type, encoding, etc.)
    processing_log JSONB, -- Data lineage complet
    kaggle_info JSONB, -- Infos publication Kaggle
    analysis_type VARCHAR(100), -- Type d'analyse demandé
    analysis_parameters JSONB, -- Paramètres de l'analyse
    analysis_results JSONB, -- Résultats de l'analyse
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table pour les logs de traitement (optionnel mais utile)
CREATE TABLE IF NOT EXISTS processing_logs (
    id SERIAL PRIMARY KEY,
    dataset_id INTEGER REFERENCES datasets(id) ON DELETE CASCADE,
    log_level VARCHAR(20) NOT NULL,
    step VARCHAR(50) NOT NULL, -- Étape du traitement
    message TEXT NOT NULL,
    details JSONB, -- Détails supplémentaires
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Créer la table des logs d'emails
CREATE TABLE IF NOT EXISTS email_logs (
    id SERIAL PRIMARY KEY,
    email_type VARCHAR(50) NOT NULL,
    dataset_id INTEGER REFERENCES datasets(id) ON DELETE SET NULL,
    recipient_email VARCHAR(255) NOT NULL,
    subject TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    error_message TEXT,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index pour les logs de traitement
CREATE INDEX IF NOT EXISTS idx_processing_logs_dataset_id ON processing_logs(dataset_id);
CREATE INDEX IF NOT EXISTS idx_processing_logs_step ON processing_logs(step);
CREATE INDEX IF NOT EXISTS idx_processing_logs_created_at ON processing_logs(created_at);

-- Index pour les logs d'emails
CREATE INDEX IF NOT EXISTS idx_email_logs_type ON email_logs(email_type);
CREATE INDEX IF NOT EXISTS idx_email_logs_status ON email_logs(status);
CREATE INDEX IF NOT EXISTS idx_email_logs_dataset_id ON email_logs(dataset_id);
CREATE INDEX IF NOT EXISTS idx_email_logs_sent_at ON email_logs(sent_at);

-- Index pour optimiser les requêtes sur la table unifiée
CREATE INDEX IF NOT EXISTS idx_datasets_user_id ON datasets(user_id);
CREATE INDEX IF NOT EXISTS idx_datasets_status ON datasets(status);
CREATE INDEX IF NOT EXISTS idx_datasets_quality_score ON datasets(quality_score);
CREATE INDEX IF NOT EXISTS idx_datasets_file_hash ON datasets(file_hash);
CREATE INDEX IF NOT EXISTS idx_datasets_created_at ON datasets(created_at);
CREATE INDEX IF NOT EXISTS idx_datasets_updated_at ON datasets(updated_at);
CREATE INDEX IF NOT EXISTS idx_datasets_analysis_type ON datasets(analysis_type);

-- Index GIN pour les colonnes JSONB (très important pour la performance)
CREATE INDEX IF NOT EXISTS idx_datasets_raw_data ON datasets USING GIN(raw_data);
CREATE INDEX IF NOT EXISTS idx_datasets_cleaned_data ON datasets USING GIN(cleaned_data);
CREATE INDEX IF NOT EXISTS idx_datasets_metadata ON datasets USING GIN(metadata);
CREATE INDEX IF NOT EXISTS idx_datasets_processing_log ON datasets USING GIN(processing_log);
CREATE INDEX IF NOT EXISTS idx_datasets_kaggle_info ON datasets USING GIN(kaggle_info);
CREATE INDEX IF NOT EXISTS idx_datasets_analysis_results ON datasets USING GIN(analysis_results);

-- Index pour les headers (tableau de textes)
CREATE INDEX IF NOT EXISTS idx_datasets_headers ON datasets USING GIN(headers);

-- Index pour les logs de traitement
CREATE INDEX IF NOT EXISTS idx_processing_logs_dataset_id ON processing_logs(dataset_id);
CREATE INDEX IF NOT EXISTS idx_processing_logs_created_at ON processing_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_processing_logs_step ON processing_logs(step);

-- Trigger pour mettre à jour le champ updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_datasets_updated_at 
    BEFORE UPDATE ON datasets 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Données de test pour la nouvelle structure unifiée
INSERT INTO datasets (
    user_id, name, status, quality_score, raw_data, headers, row_count, 
    file_size, file_hash, metadata, analysis_type, analysis_parameters, analysis_results
) VALUES
(
    'test_user', 
    'regression_dataset_1', 
    'cleaned', 
    8.5,
    '[{"x": 1, "y": 2}, {"x": 2, "y": 4}, {"x": 3, "y": 6}, {"x": 4, "y": 8}, {"x": 5, "y": 10}]',
    ARRAY['x', 'y'],
    5,
    1024,
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
    '{"mime_type": "text/csv", "encoding": "utf-8", "separator": ",", "has_header": true}',
    'regression/linear',
    '{"x_columns": ["x"], "y_column": "y"}',
    '{"coefficients": [2.0], "intercept": 0.0, "r2": 1.0}'
),
(
    'test_user', 
    'classification_dataset_1', 
    'premium', 
    9.2,
    '[{"feature1": 1.0, "feature2": 2.1, "target": 0}, {"feature1": 2.0, "feature2": 3.2, "target": 0}, {"feature1": 3.0, "feature2": 4.1, "target": 1}, {"feature1": 4.0, "feature2": 5.2, "target": 1}]',
    ARRAY['feature1', 'feature2', 'target'],
    4,
    2048,
    'b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef12345678',
    '{"mime_type": "text/csv", "encoding": "utf-8", "separator": ",", "has_header": true}',
    'classification/supervised',
    '{"feature_columns": ["feature1", "feature2"], "target_column": "target"}',
    '{"accuracy": 0.95, "precision": 0.93, "recall": 0.97}'
);

-- Insérer quelques logs de traitement exemple
INSERT INTO processing_logs (dataset_id, log_level, step, message, details) VALUES
(1, 'INFO', 'upload', 'Dataset uploaded successfully', '{"file_size": 1024, "validation": "passed"}'),
(1, 'INFO', 'cleaning', 'Data cleaning completed', '{"missing_values": 0, "outliers_removed": 0}'),
(1, 'INFO', 'analysis', 'Linear regression analysis completed', '{"r2_score": 1.0}'),
(2, 'INFO', 'upload', 'Dataset uploaded successfully', '{"file_size": 2048, "validation": "passed"}'),
(2, 'INFO', 'cleaning', 'Data cleaning and feature engineering completed', '{"missing_values": 0, "features_added": 2}'),
(2, 'INFO', 'analysis', 'Classification analysis completed', '{"accuracy": 0.95}'),
(2, 'INFO', 'quality_check', 'Quality assessment passed', '{"score": 9.2, "status": "premium"}');

COMMIT;
