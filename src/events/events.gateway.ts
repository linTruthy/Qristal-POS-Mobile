import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';

// Allow any origin for now to avoid CORS issues during dev/testing across devices
@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class EventsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private logger: Logger = new Logger('EventsGateway');

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  // --- Methods to emit events from other services ---

  // Call this when an order is received from the POS
  emitNewOrder(orderData: any) {
    this.server.emit('newOrder', orderData);
  }

  // Call this when inventory is updated
  emitInventoryUpdate(inventoryData: any) {
    this.server.emit('inventoryUpdate', inventoryData);
  }
}