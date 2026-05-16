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

void WhisperClient::setBusy(bool b) {
    if (m_busy == b) return;
    m_busy = b;
    emit busyChanged();
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
    setBusy(true);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            const QString msg = QStringLiteral("HTTP error: ") + reply->errorString();
            qWarning() << "[whisper]" << msg << "body:" << reply->readAll().left(500);
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
        reply->deleteLater();
    });
}
