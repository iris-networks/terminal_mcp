package sse

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"
)

// Event represents an SSE event
type Event struct {
	Type      string      `json:"type"`
	SessionID string      `json:"sessionId"`
	Data      interface{} `json:"data"`
	Timestamp string      `json:"timestamp"`
}

// Client represents an SSE client connection
type Client struct {
	ID        string
	SessionID string
	Channel   chan Event
	Done      chan bool
}

// Broadcaster manages SSE connections and event distribution
type Broadcaster struct {
	clients map[string]*Client
	mutex   sync.RWMutex
}

// NewBroadcaster creates a new SSE broadcaster
func NewBroadcaster() *Broadcaster {
	return &Broadcaster{
		clients: make(map[string]*Client),
	}
}

// AddClient adds a new SSE client
func (b *Broadcaster) AddClient(clientID, sessionID string) *Client {
	b.mutex.Lock()
	defer b.mutex.Unlock()

	client := &Client{
		ID:        clientID,
		SessionID: sessionID,
		Channel:   make(chan Event, 100), // Buffered channel to prevent blocking
		Done:      make(chan bool),
	}

	b.clients[clientID] = client
	log.Printf("SSE client added: %s for session: %s", clientID, sessionID)
	
	return client
}

// RemoveClient removes an SSE client
func (b *Broadcaster) RemoveClient(clientID string) {
	b.mutex.Lock()
	defer b.mutex.Unlock()

	if client, exists := b.clients[clientID]; exists {
		close(client.Channel)
		close(client.Done)
		delete(b.clients, clientID)
		log.Printf("SSE client removed: %s", clientID)
	}
}

// BroadcastToSession sends an event to all clients listening to a specific session
func (b *Broadcaster) BroadcastToSession(sessionID string, eventType string, data interface{}) {
	b.mutex.RLock()
	defer b.mutex.RUnlock()

	event := Event{
		Type:      eventType,
		SessionID: sessionID,
		Data:      data,
		Timestamp: time.Now().Format(time.RFC3339),
	}

	for _, client := range b.clients {
		if client.SessionID == sessionID {
			select {
			case client.Channel <- event:
				// Event sent successfully
			default:
				// Channel full, client may be slow
				log.Printf("Warning: SSE client %s channel full, dropping event", client.ID)
			}
		}
	}

	log.Printf("Broadcasted %s event to session %s", eventType, sessionID)
}

// BroadcastToAll sends an event to all connected clients
func (b *Broadcaster) BroadcastToAll(eventType string, data interface{}) {
	b.mutex.RLock()
	defer b.mutex.RUnlock()

	event := Event{
		Type:      eventType,
		SessionID: "all",
		Data:      data,
		Timestamp: time.Now().Format(time.RFC3339),
	}

	for _, client := range b.clients {
		select {
		case client.Channel <- event:
			// Event sent successfully
		default:
			// Channel full, client may be slow
			log.Printf("Warning: SSE client %s channel full, dropping event", client.ID)
		}
	}

	log.Printf("Broadcasted %s event to all clients", eventType)
}

// GetClientCount returns the number of connected clients
func (b *Broadcaster) GetClientCount() int {
	b.mutex.RLock()
	defer b.mutex.RUnlock()
	return len(b.clients)
}

// GetSessionClients returns the number of clients for a specific session
func (b *Broadcaster) GetSessionClients(sessionID string) int {
	b.mutex.RLock()
	defer b.mutex.RUnlock()
	
	count := 0
	for _, client := range b.clients {
		if client.SessionID == sessionID {
			count++
		}
	}
	return count
}

// FormatSSEMessage formats an event as an SSE message
func FormatSSEMessage(event Event) string {
	eventData, _ := json.Marshal(event)
	return fmt.Sprintf("event: %s\ndata: %s\n\n", event.Type, string(eventData))
}