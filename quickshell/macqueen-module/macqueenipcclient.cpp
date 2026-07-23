/*
    SPDX-FileCopyrightText: 2026 The MacqueenDE contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#include "macqueenipcclient.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>

namespace
{

template<typename T>
T converted(const QVariant &value)
{
    if (value.canConvert<QDBusArgument>()) {
        return qdbus_cast<T>(value.value<QDBusArgument>());
    }
    if (value.canConvert<T>()) {
        return value.value<T>();
    }
    return {};
}

QVariantList mapList(const QVariant &value)
{
    const QVariantList raw = converted<QVariantList>(value);
    QVariantList result;
    result.reserve(raw.size());
    for (const QVariant &entry : raw) {
        if (entry.canConvert<QDBusArgument>()) {
            result.append(qdbus_cast<QVariantMap>(entry.value<QDBusArgument>()));
        } else {
            result.append(entry.toMap());
        }
    }
    return result;
}

}

MacqueenIpcClient::MacqueenIpcClient(QObject *parent)
    : QObject(parent)
    , m_watcher(QString::fromLatin1(Service),
                QDBusConnection::sessionBus(),
                QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration)
{
    connect(&m_watcher, &QDBusServiceWatcher::serviceRegistered, this, &MacqueenIpcClient::handleServiceRegistered);
    connect(&m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, &MacqueenIpcClient::handleServiceUnregistered);

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(QString::fromLatin1(Service), QString::fromLatin1(Path), QString::fromLatin1(Interface),
                QStringLiteral("windowAdded"), this, SLOT(handleWindowAdded(QString)));
    bus.connect(QString::fromLatin1(Service), QString::fromLatin1(Path), QString::fromLatin1(Interface),
                QStringLiteral("windowRemoved"), this, SLOT(handleWindowRemoved(QString)));
    bus.connect(QString::fromLatin1(Service), QString::fromLatin1(Path), QString::fromLatin1(Interface),
                QStringLiteral("windowChanged"), this, SLOT(handleWindowChanged(QString,QStringList)));
    bus.connect(QString::fromLatin1(Service), QString::fromLatin1(Path), QString::fromLatin1(Interface),
                QStringLiteral("activeWindowChanged"), this, SLOT(handleActiveWindowChanged(QString)));
    bus.connect(QString::fromLatin1(Service), QString::fromLatin1(Path), QString::fromLatin1(Interface),
                QStringLiteral("outputsChanged"), this, SLOT(refreshOutputs()));
    bus.connect(QString::fromLatin1(Service), QString::fromLatin1(Path), QString::fromLatin1(Interface),
                QStringLiteral("workspacesChanged"), this, SLOT(refreshWorkspaces()));

    const QDBusReply<bool> registered = bus.interface()->isServiceRegistered(QString::fromLatin1(Service));
    if (registered.isValid() && registered.value()) {
        handleServiceRegistered();
    }
}

bool MacqueenIpcClient::available() const
{
    return m_available;
}

uint MacqueenIpcClient::protocolVersion() const
{
    return m_protocolVersion;
}

QString MacqueenIpcClient::compositorVersion() const
{
    return m_compositorVersion;
}

QVariantMap MacqueenIpcClient::activeWindow() const
{
    return m_activeWindow;
}

QVariantList MacqueenIpcClient::windows() const
{
    return m_windows;
}

QVariantList MacqueenIpcClient::outputs() const
{
    return m_outputs;
}

QVariantList MacqueenIpcClient::workspaces() const
{
    return m_workspaces;
}

void MacqueenIpcClient::refresh()
{
    if (!m_available) {
        return;
    }
    refreshVersions();
    refreshWindows();
    refreshActiveWindow();
    refreshOutputs();
    refreshWorkspaces();
}

bool MacqueenIpcClient::activateWorkspace(const QString &id)
{
    return call(QStringLiteral("activateWorkspace"), {id}).toBool();
}

QString MacqueenIpcClient::createWorkspace(uint position, const QString &name)
{
    return call(QStringLiteral("createWorkspace"), {position, name}).toString();
}

bool MacqueenIpcClient::removeWorkspace(const QString &id)
{
    return call(QStringLiteral("removeWorkspace"), {id}).toBool();
}

bool MacqueenIpcClient::renameWorkspace(const QString &id, const QString &name)
{
    return call(QStringLiteral("renameWorkspace"), {id, name}).toBool();
}

void MacqueenIpcClient::handleServiceRegistered()
{
    if (!m_available) {
        m_available = true;
        Q_EMIT availableChanged();
    }
    refresh();
}

void MacqueenIpcClient::handleServiceUnregistered()
{
    clear();
}

void MacqueenIpcClient::handleWindowAdded(const QString &id)
{
    Q_UNUSED(id)
    refreshWindows();
}

void MacqueenIpcClient::handleWindowRemoved(const QString &id)
{
    Q_UNUSED(id)
    refreshWindows();
    refreshActiveWindow();
}

void MacqueenIpcClient::handleWindowChanged(const QString &id, const QStringList &fields)
{
    Q_UNUSED(id)
    Q_UNUSED(fields)
    refreshWindows();
    refreshActiveWindow();
}

void MacqueenIpcClient::handleActiveWindowChanged(const QString &id)
{
    Q_UNUSED(id)
    refreshActiveWindow();
    refreshWindows();
}

void MacqueenIpcClient::refreshOutputs()
{
    const QVariantList value = mapList(call(QStringLiteral("outputs")));
    if (m_outputs != value) {
        m_outputs = value;
        Q_EMIT outputsChanged();
    }
}

void MacqueenIpcClient::refreshWorkspaces()
{
    const QVariantList value = mapList(call(QStringLiteral("workspaces")));
    if (m_workspaces != value) {
        m_workspaces = value;
        Q_EMIT workspacesChanged();
    }
}

QVariant MacqueenIpcClient::call(const QString &method, const QVariantList &arguments) const
{
    QDBusInterface interface(QString::fromLatin1(Service),
                             QString::fromLatin1(Path),
                             QString::fromLatin1(Interface),
                             QDBusConnection::sessionBus());
    const QDBusMessage reply = interface.callWithArgumentList(QDBus::Block, method, arguments);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        return reply.arguments().constFirst();
    }
    return {};
}

void MacqueenIpcClient::refreshVersions()
{
    const uint protocol = call(QStringLiteral("protocolVersion")).toUInt();
    const QString compositor = call(QStringLiteral("compositorVersion")).toString();
    if (m_protocolVersion != protocol || m_compositorVersion != compositor) {
        m_protocolVersion = protocol;
        m_compositorVersion = compositor;
        Q_EMIT versionsChanged();
    }
}

void MacqueenIpcClient::refreshWindows()
{
    const QVariantList value = mapList(call(QStringLiteral("windows")));
    if (m_windows != value) {
        m_windows = value;
        Q_EMIT windowsChanged();
    }
}

void MacqueenIpcClient::refreshActiveWindow()
{
    const QVariantMap value = converted<QVariantMap>(call(QStringLiteral("activeWindow")));
    if (m_activeWindow != value) {
        m_activeWindow = value;
        Q_EMIT activeWindowChanged();
    }
}

void MacqueenIpcClient::clear()
{
    const bool wasAvailable = m_available;
    m_available = false;
    m_protocolVersion = 0;
    m_compositorVersion.clear();
    m_activeWindow.clear();
    m_windows.clear();
    m_outputs.clear();
    m_workspaces.clear();

    if (wasAvailable) {
        Q_EMIT availableChanged();
    }
    Q_EMIT versionsChanged();
    Q_EMIT activeWindowChanged();
    Q_EMIT windowsChanged();
    Q_EMIT outputsChanged();
    Q_EMIT workspacesChanged();
}
