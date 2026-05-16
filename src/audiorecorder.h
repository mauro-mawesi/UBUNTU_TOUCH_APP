#ifndef AUDIORECORDER_H
#define AUDIORECORDER_H

#include <QObject>
#include <QString>
#include <QAudioRecorder>

class AudioRecorder : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(QString outputFile READ outputFile NOTIFY outputFileChanged)

public:
    explicit AudioRecorder(QObject *parent = nullptr);
    bool recording() const;
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
};

#endif // AUDIORECORDER_H
