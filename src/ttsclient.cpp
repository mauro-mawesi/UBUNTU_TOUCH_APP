#include "ttsclient.h"

#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <QDebug>

TtsClient::TtsClient(QObject *parent) : QObject(parent) {}

TtsClient::~TtsClient() {
    // App shutdown shouldn't wait for an in-flight reply. cancel() is safe
    // when idle (m_currentReply is QPointer and may already be null).
    cancel();
}

void TtsClient::setBusy(bool b) {
    if (m_busy == b) return;
    m_busy = b;
    emit busyChanged();
}

void TtsClient::cancel() {
    if (m_currentReply) {
        m_currentReply->abort();
    }
}

void TtsClient::synthesize(const QString &serverUrl, const QString &text,
                            const QString &voice, const QString &format,
                            const QString &apiKey) {
    if (text.trimmed().isEmpty()) {
        emit errorOccurred(QStringLiteral("Empty text"));
        return;
    }

    const QString fmt = format.isEmpty() ? QStringLiteral("mp3") : format;

    QJsonObject body;
    body[QStringLiteral("model")] = QStringLiteral("kokoro");
    body[QStringLiteral("input")] = text;
    body[QStringLiteral("voice")] = voice.isEmpty() ? QStringLiteral("af_bella") : voice;
    body[QStringLiteral("response_format")] = fmt;

    QUrl url(serverUrl);
    if (!url.path().contains(QStringLiteral("audio/speech"))) {
        QString p = url.path();
        while (p.endsWith('/')) p.chop(1);
        url.setPath(p + QStringLiteral("/v1/audio/speech"));
    }

    qDebug() << "[tts] POST" << url.toString() << "voice=" << voice << "len=" << text.size();

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    if (!apiKey.isEmpty()) {
        req.setRawHeader("Authorization", QByteArray("Bearer ") + apiKey.toUtf8());
    }

    QNetworkReply *reply = m_nam.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    m_currentReply = reply;
    setBusy(true);

    connect(reply, &QNetworkReply::finished, this, [this, reply, fmt]() {
        setBusy(false);
        if (reply->error() == QNetworkReply::OperationCanceledError) {
            qDebug() << "[tts] cancelled";
            reply->deleteLater();
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            const QString msg = QStringLiteral("HTTP error: ") + reply->errorString();
            // Drop response body — TTS errors can echo request snippets.
            qWarning() << "[tts]" << msg << "(body redacted)";
            emit errorOccurred(msg);
            reply->deleteLater();
            return;
        }

        const QByteArray data = reply->readAll();
        if (data.isEmpty()) {
            emit errorOccurred(QStringLiteral("Empty audio response"));
            reply->deleteLater();
            return;
        }

        const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        QDir().mkpath(dir);

        // Bound the TTS cache: keep at most one tts_* file on disk by sweeping
        // prior synth outputs (any extension) before writing the new one.
        // A MediaPlayer currently playing a deleted file keeps its open handle
        // valid on Linux until the player closes it.
        {
            QDir cacheDir(dir);
            const QStringList stale = cacheDir.entryList(
                QStringList() << QStringLiteral("tts_*"), QDir::Files);
            for (const QString &name : stale) QFile::remove(cacheDir.filePath(name));
        }

        const QString path = QStringLiteral("%1/tts_%2.%3")
                                 .arg(dir)
                                 .arg(QDateTime::currentMSecsSinceEpoch())
                                 .arg(fmt);

        QFile f(path);
        if (!f.open(QIODevice::WriteOnly)) {
            emit errorOccurred(QStringLiteral("Cannot write: ") + path);
            reply->deleteLater();
            return;
        }
        f.write(data);
        f.close();
        qDebug() << "[tts] audio saved" << path << "bytes=" << data.size();
        emit audioReady(path);
        reply->deleteLater();
    });
}
