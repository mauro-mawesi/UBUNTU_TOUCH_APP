#include "whisperclient.h"

#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QHttpPart>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QUrl>
#include <QDebug>

WhisperClient::WhisperClient(QObject *parent) : QObject(parent) {}

WhisperClient::~WhisperClient() {
    // App shutdown shouldn't wait for an in-flight transcription. cancel() is
    // safe when idle (m_currentReply is QPointer and may already be null).
    cancel();
}

void WhisperClient::setBusy(bool b) {
    if (m_busy == b) return;
    m_busy = b;
    emit busyChanged();
}

void WhisperClient::cancel() {
    if (m_currentReply) {
        m_currentReply->abort();
    }
}

void WhisperClient::transcribe(const QString &serverUrl, const QString &filePath,
                                const QString &language, const QString &model) {
    QFile *file = new QFile(filePath);
    if (!file->open(QIODevice::ReadOnly)) {
        emit errorOccurred(QStringLiteral("Cannot open file: ") + filePath);
        delete file;
        return;
    }

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    QHttpPart modelPart;
    modelPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                        QVariant(QStringLiteral("form-data; name=\"model\"")));
    modelPart.setBody(model.isEmpty()
                          ? QByteArrayLiteral("Systran/faster-whisper-small")
                          : model.toUtf8());
    multiPart->append(modelPart);

    if (!language.isEmpty()) {
        QHttpPart langPart;
        langPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                           QVariant(QStringLiteral("form-data; name=\"language\"")));
        langPart.setBody(language.toUtf8());
        multiPart->append(langPart);
    }

    const QString ext = QFileInfo(filePath).suffix().toLower();
    QString mime = QStringLiteral("application/octet-stream");
    if (ext == QStringLiteral("wav")) mime = QStringLiteral("audio/wav");
    else if (ext == QStringLiteral("ogg")) mime = QStringLiteral("audio/ogg");
    else if (ext == QStringLiteral("mp3")) mime = QStringLiteral("audio/mpeg");
    else if (ext == QStringLiteral("m4a")) mime = QStringLiteral("audio/mp4");
    else if (ext == QStringLiteral("webm")) mime = QStringLiteral("audio/webm");

    QHttpPart filePart;
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant(mime));
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QVariant(QStringLiteral("form-data; name=\"file\"; filename=\"audio.%1\"").arg(ext.isEmpty() ? "wav" : ext)));
    filePart.setBodyDevice(file);
    file->setParent(multiPart);
    multiPart->append(filePart);

    QUrl url(serverUrl);
    if (!url.path().contains(QStringLiteral("audio/transcriptions"))) {
        QString p = url.path();
        while (p.endsWith('/')) p.chop(1);
        url.setPath(p + QStringLiteral("/v1/audio/transcriptions"));
    }

    qDebug() << "[whisper] POST" << url.toString() << "file=" << filePath
             << "lang=" << language;

    QNetworkRequest req(url);
    QNetworkReply *reply = m_nam.post(req, multiPart);
    multiPart->setParent(reply);
    m_currentReply = reply;
    setBusy(true);

    connect(reply, &QNetworkReply::finished, this, [this, reply, filePath]() {
        setBusy(false);
        if (reply->error() == QNetworkReply::OperationCanceledError) {
            qDebug() << "[whisper] cancelled";
            if (!filePath.isEmpty()) QFile::remove(filePath);
            reply->deleteLater();
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            const QString msg = QStringLiteral("HTTP error: ") + reply->errorString();
            // Drop response body — Whisper error payloads sometimes echo
            // diagnostics. errorString() already carries the salient cause.
            qWarning() << "[whisper]" << msg << "(body redacted)";
            emit errorOccurred(msg);
        } else {
            const QByteArray data = reply->readAll();
            QJsonParseError err;
            const QJsonDocument doc = QJsonDocument::fromJson(data, &err);
            if (err.error != QJsonParseError::NoError) {
                emit errorOccurred(QStringLiteral("parse error: ") + err.errorString());
            } else {
                const QString text = doc.object().value(QStringLiteral("text")).toString();
                qDebug() << "[whisper] transcribed len=" << text.size();
                emit transcribed(text);
            }
        }
        // The recording is single-use: once Whisper has accepted (or rejected)
        // it, the local file is no longer needed. Keeping it around accumulates
        // personal voice data in the app cache. Unlinking is safe even though
        // the QFile* is still open (parented to multiPart → reply); on Linux
        // the inode survives until the descriptor closes during deleteLater().
        if (!filePath.isEmpty()) QFile::remove(filePath);
        reply->deleteLater();
    });
}
