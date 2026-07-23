/*
    SPDX-FileCopyrightText: 2026 The MacqueenDE contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#pragma once

#include <QDBusServiceWatcher>
#include <QObject>
#include <QQmlEngine>
#include <QVariantList>
#include <QVariantMap>

class MacqueenIpcClient : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Macqueen)
    QML_SINGLETON

    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(uint protocolVersion READ protocolVersion NOTIFY versionsChanged)
    Q_PROPERTY(QString compositorVersion READ compositorVersion NOTIFY versionsChanged)
    Q_PROPERTY(QVariantMap activeWindow READ activeWindow NOTIFY activeWindowChanged)
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(QVariantList outputs READ outputs NOTIFY outputsChanged)
    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)

public:
    explicit MacqueenIpcClient(QObject *parent = nullptr);

    bool available() const;
    uint protocolVersion() const;
    QString compositorVersion() const;
    QVariantMap activeWindow() const;
    QVariantList windows() const;
    QVariantList outputs() const;
    QVariantList workspaces() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool activateWorkspace(const QString &id);
    Q_INVOKABLE QString createWorkspace(uint position, const QString &name = QString());
    Q_INVOKABLE bool removeWorkspace(const QString &id);
    Q_INVOKABLE bool renameWorkspace(const QString &id, const QString &name);

Q_SIGNALS:
    void availableChanged();
    void versionsChanged();
    void activeWindowChanged();
    void windowsChanged();
    void outputsChanged();
    void workspacesChanged();

private Q_SLOTS:
    void handleServiceRegistered();
    void handleServiceUnregistered();
    void handleWindowAdded(const QString &id);
    void handleWindowRemoved(const QString &id);
    void handleWindowChanged(const QString &id, const QStringList &fields);
    void handleActiveWindowChanged(const QString &id);
    void refreshOutputs();
    void refreshWorkspaces();

private:
    QVariant call(const QString &method, const QVariantList &arguments = {}) const;
    void refreshVersions();
    void refreshWindows();
    void refreshActiveWindow();
    void clear();

    static constexpr auto Service = "org.macqueen.Compositor1";
    static constexpr auto Path = "/org/macqueen/Compositor1";
    static constexpr auto Interface = "org.macqueen.Compositor1";

    QDBusServiceWatcher m_watcher;
    bool m_available = false;
    uint m_protocolVersion = 0;
    QString m_compositorVersion;
    QVariantMap m_activeWindow;
    QVariantList m_windows;
    QVariantList m_outputs;
    QVariantList m_workspaces;
};
