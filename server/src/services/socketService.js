const { Server } = require('socket.io');
const logger = require('../config/logger');
let io;

const initSocket = (server, corsOptions) => {
  io = new Server(server, {
    cors: {
      ...corsOptions,
      methods: ["GET", "POST"]
    }
  });

  io.on('connection', (socket) => {
    logger.info(`New client connected: ${socket.id}`);

    // Join room based on role
    socket.on('join_dashboard', (role) => {
      socket.join(`dashboard_${role}`);
      logger.info(`Socket ${socket.id} joined dashboard_${role}`);
    });

    // Join room based on user ID for targeted notifications
    socket.on('join_user', (userId) => {
      socket.join(`user_${userId}`);
      logger.info(`Socket ${socket.id} joined user_${userId}`);
    });

    // Join specific entity room (e.g., student ID or class ID)
    socket.on('join_room', (roomName) => {
      socket.join(roomName);
      logger.info(`Socket ${socket.id} joined ${roomName}`);
    });

    socket.on('join_trip', (data) => {
      const roomName = `trip_${data.tripId}`;
      socket.join(roomName);
      logger.info(`Socket ${socket.id} joined ${roomName}`);
    });

    socket.on('leave_room', (roomName) => {
      socket.leave(roomName);
      logger.info(`Socket ${socket.id} left ${roomName}`);
    });

    socket.on('leave_trip', (data) => {
      const roomName = `trip_${data.tripId}`;
      socket.leave(roomName);
      logger.info(`Socket ${socket.id} left ${roomName}`);
    });


    // Real-time chat message broker
    socket.on('send_message', (data) => {
      const { senderId, senderName, recipientId, text } = data;
      if (!recipientId || !text) {
        logger.warn(`Invalid send_message received from socket ${socket.id}:`, data);
        return;
      }

      logger.info(`📨 Chat relay: ${senderName} (${senderId}) -> ${recipientId}: "${text.substring(0, 30)}..."`);

      // Emit receive_message event to the targeted user room
      io.to(`user_${recipientId}`).emit('receive_message', {
        senderId,
        senderName,
        text,
        timestamp: new Date().toISOString()
      });
    });

    socket.on('disconnect', () => {
      logger.info(`Client disconnected: ${socket.id}`);
    });
  });

  return io;
};

const getIO = () => {
  if (!io) {
    throw new Error('Socket.io not initialized');
  }
  return io;
};

const emitEvent = (event, data, target = null) => {
  if (!io) return;
  
  if (target) {
    let room = target;
    
    // Check if target is already a prefixed room
    const isPrefixed = target.startsWith('dashboard_') || 
                      target.startsWith('class_') || 
                      target.startsWith('student_') || 
                      target.startsWith('user_') || 
                      target.startsWith('trip_');
    
    if (!isPrefixed) {
      room = `dashboard_${target}`;
    }

    io.to(room).emit(event, data);
    logger.debug(`Socket emit: [${event}] to [${room}]`);

    // Also emit to SUPER_ADMIN and ADMIN by default for broad dashboard/role events
    // We avoid doing this for private user_ or trip_ rooms unless explicitly targeted
    if (room.startsWith('dashboard_') && !room.includes('SUPER_ADMIN') && !room.includes('ADMIN')) {
        io.to('dashboard_SUPER_ADMIN').emit(event, data);
        io.to('dashboard_ADMIN').emit(event, data);
    }
  } else {
    io.emit(event, data);
  }
};

module.exports = {
  initSocket,
  getIO,
  emitEvent
};
