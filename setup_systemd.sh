#!/bin/sh
cp -f /home/root/AI_Notes/ai-exporter.service /etc/systemd/system/ai-exporter.service
cp -f /home/root/AI_Notes/ai-exporter.path /etc/systemd/system/ai-exporter.path
systemctl daemon-reload
systemctl enable --now ai-exporter.path
