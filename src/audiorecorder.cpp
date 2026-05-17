#include "audiorecorder.h"

#include <QAudioEncoderSettings>
#include <QVideoEncoderSettings>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QUrl>
#include <QDebug>

AudioRecorder::AudioRecorder(QObject *parent)
    : QObject(parent), m_recorder(new QAudioRecorder(this))
{
    // Mirror ttsclient's tts_* sweep: if a previous run crashed between
    // start() and the WhisperClient upload, rec_*.{wav,ogg,mp3,dat} files
    // pile up in CacheLocation. Best-effort cleanup at startup keeps the
    // cache bounded — the WhisperClient itself deletes the file post-upload,
    // so we only ever expect leftovers from abnormal exits.
    {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        QDir cacheDir(dir);
        const QStringList stale = cacheDir.entryList(
            QStringList() << QStringLiteral("rec_*"), QDir::Files);
        for (const QString &name : stale) cacheDir.remove(name);
    }

    // Probe input availability once. Empty under clickable desktop (Docker
    // has no audio device); the QML side reads `available` to grey out the
    // mic button + show an Accessible.description tooltip before the user
    // taps. `audioInputs()` is the QAudioRecorder API that Qt 5.12 exposes
    // for this — QAudioDeviceInfo::availableDevices works too but couples
    // us to multimedia internals.
    {
        const QStringList inputs = m_recorder->audioInputs();
        m_available = !inputs.isEmpty();
        qDebug() << "[AudioRecorder] inputs:" << inputs
                 << "available=" << m_available;
    }

    configureSettings();

    connect(m_recorder, &QMediaRecorder::stateChanged,
            this, [this](QMediaRecorder::State state) {
        emit recordingChanged();
        if (state == QMediaRecorder::StoppedState && !m_outputFile.isEmpty()) {
            qDebug() << "[AudioRecorder] stopped, file:" << m_outputFile;
            emit recordingFinished(m_outputFile);
        }
    });

    connect(m_recorder,
            static_cast<void (QMediaRecorder::*)(QMediaRecorder::Error)>(&QMediaRecorder::error),
            this, [this](QMediaRecorder::Error err) {
        Q_UNUSED(err);
        const QString msg = m_recorder->errorString();
        qWarning() << "[AudioRecorder] error:" << msg;
        emit errorOccurred(msg);
    });
}

void AudioRecorder::configureSettings() {
    const QStringList codecs = m_recorder->supportedAudioCodecs();
    const QStringList containers = m_recorder->supportedContainers();
    qDebug() << "[AudioRecorder] codecs available:" << codecs;
    qDebug() << "[AudioRecorder] containers available:" << containers;

    // Preference order: WAV (best for Whisper), OGG Vorbis, anything else
    struct Combo {
        const char *codec;
        const char *container;
        const char *ext;
    };
    const QVector<Combo> preferred = {
        { "audio/PCM",     "audio/x-wav", "wav" },
        { "audio/x-raw",   "audio/x-wav", "wav" },
        { "audio/pcm",     "wav",         "wav" },
        { "audio/vorbis",  "audio/ogg",   "ogg" },
        { "audio/x-vorbis","ogg",         "ogg" },
        { "audio/opus",    "audio/ogg",   "ogg" },
        { "audio/mpeg",    "mp3",         "mp3" }
    };

    QString chosenCodec, chosenContainer, chosenExt;
    for (const auto &c : preferred) {
        bool codecOk = codecs.contains(c.codec, Qt::CaseInsensitive);
        bool containerOk = containers.contains(c.container, Qt::CaseInsensitive);
        if (codecOk && containerOk) {
            chosenCodec = c.codec;
            chosenContainer = c.container;
            chosenExt = c.ext;
            break;
        }
    }

    if (chosenCodec.isEmpty()) {
        // last resort: just use first codec available
        if (!codecs.isEmpty()) chosenCodec = codecs.first();
        if (!containers.isEmpty()) chosenContainer = containers.first();
        chosenExt = QStringLiteral("dat");
    }

    qDebug() << "[AudioRecorder] using codec=" << chosenCodec
             << "container=" << chosenContainer
             << "ext=" << chosenExt;

    m_extension = chosenExt;

    QAudioEncoderSettings settings;
    settings.setCodec(chosenCodec);
    settings.setSampleRate(16000);
    settings.setChannelCount(1);
    settings.setQuality(QMultimedia::HighQuality);
    settings.setEncodingMode(QMultimedia::ConstantQualityEncoding);

    m_recorder->setEncodingSettings(settings, QVideoEncoderSettings(), chosenContainer);
    m_recorder->setContainerFormat(chosenContainer);
}

bool AudioRecorder::recording() const {
    return m_recorder->state() == QMediaRecorder::RecordingState;
}

void AudioRecorder::start() {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    m_outputFile = QStringLiteral("%1/rec_%2.%3")
                        .arg(dir)
                        .arg(QDateTime::currentMSecsSinceEpoch())
                        .arg(m_extension);
    m_recorder->setOutputLocation(QUrl::fromLocalFile(m_outputFile));
    qDebug() << "[AudioRecorder] start ->" << m_outputFile;
    m_recorder->record();
    emit outputFileChanged();
}

void AudioRecorder::stop() {
    qDebug() << "[AudioRecorder] stop requested";
    m_recorder->stop();
}
