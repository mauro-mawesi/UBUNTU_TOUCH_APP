#ifndef AUDIORECORDER_H
#define AUDIORECORDER_H

#include <QObject>
#include <QString>
#include <QAudioRecorder>

class AudioRecorder : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(QString outputFile READ outputFile NOTIFY outputFileChanged)
    // Snapshot taken once at construction: whether the platform exposes at
    // least one usable audio input. False under `clickable desktop` (Docker
    // has no audio device) so the UI can grey out the mic with an upfront
    // tooltip instead of failing on the first tap. CONSTANT — the input set
    // doesn't appear/disappear during the app's lifetime.
    Q_PROPERTY(bool available READ available CONSTANT)

public:
    explicit AudioRecorder(QObject *parent = nullptr);
    bool recording() const;
    bool available() const { return m_available; }
    QString outputFile() const { return m_outputFile; }

public slots:
    void start();
    void stop();

signals:
    void recordingChanged();
    void outputFileChanged();
    void recordingFinished(const QString &filePath);
    void errorOccurred(const QString &message);

private:
    void configureSettings();
    QAudioRecorder *m_recorder;
    QString m_outputFile;
    QString m_extension = QStringLiteral("wav");
    bool m_available = false;
};

#endif // AUDIORECORDER_H
