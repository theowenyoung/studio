import Fastify from 'fastify'
import { PrismaClient } from '@prisma/client'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const prisma = new PrismaClient()
const fastify = Fastify({ 
  logger: { 
    level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
    transport: process.env.NODE_ENV === 'development' ? {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: true,
        ignore: 'pid,hostname'
      }
    } : undefined
  }
})

// 注册插件
await fastify.register(import('@fastify/cors'), {
  origin: process.env.NODE_ENV === 'development' ? true : [
    'http://localhost:3000',
    'http://localhost:5173'
  ]
})

// 静态文件服务（生产环境）
if (process.env.NODE_ENV === 'production') {
  await fastify.register(import('@fastify/static'), {
    root: path.join(__dirname, '../dist/client'),
    prefix: '/'
  })
}

// 类型定义
interface CreateRecordBody {
  title: string
  content?: string
}

// API 路由
fastify.get('/health', async (_request, reply) => {
  try {
    // 测试数据库连接
    await prisma.$queryRaw`SELECT 1`
    return { 
      status: 'ok', 
      timestamp: new Date().toISOString(),
      database: 'connected'
    }
  } catch (error) {
    reply.code(503)
    return { 
      status: 'error', 
      timestamp: new Date().toISOString(),
      database: 'disconnected',
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
})

// 获取记录
fastify.get('/api/records', async (_request, reply) => {
  try {
    const records = await prisma.demoRecord.findMany({
      orderBy: { createdAt: 'desc' }
    })
    return { success: true, data: records }
  } catch (error) {
    fastify.log.error(error)
    reply.code(500)
    return { 
      success: false, 
      error: error instanceof Error ? error.message : 'Internal server error'
    }
  }
})

// 创建记录
fastify.post<{ Body: CreateRecordBody }>('/api/records', {
  schema: {
    body: {
      type: 'object',
      required: ['title'],
      properties: {
        title: { type: 'string', minLength: 1, maxLength: 255 },
        content: { type: 'string', maxLength: 1000 }
      }
    },
    response: {
      200: {
        type: 'object',
        properties: {
          success: { type: 'boolean' },
          data: {
            type: 'object',
            properties: {
              id: { type: 'number' },
              title: { type: 'string' },
              content: { type: 'string' },
              createdAt: { type: 'string' }
            }
          }
        }
      }
    }
  }
}, async (request, reply) => {
  try {
    const { title, content } = request.body
    const record = await prisma.demoRecord.create({
      data: { title, content: content || '' }
    })
    return { success: true, data: record }
  } catch (error) {
    fastify.log.error(error)
    reply.code(500)
    return { 
      success: false, 
      error: error instanceof Error ? error.message : 'Internal server error'
    }
  }
})

// SPA fallback（生产环境）
if (process.env.NODE_ENV === 'production') {
  fastify.setNotFoundHandler(async (request, reply) => {
    // API 请求返回 404
    if (request.url.startsWith('/api/')) {
      reply.code(404)
      return { success: false, error: 'API endpoint not found' }
    }
    
    // 其他请求返回 index.html（SPA 路由）
    reply.type('text/html')
    return reply.sendFile('index.html')
  })
}

// 优雅关闭
const signals = ['SIGINT', 'SIGTERM']
signals.forEach((signal) => {
  process.on(signal, async () => {
    fastify.log.info(`收到 ${signal}，正在优雅关闭...`)
    try {
      await prisma.$disconnect()
      await fastify.close()
      process.exit(0)
    } catch (err) {
      fastify.log.error(err)
      process.exit(1)
    }
  })
})

// 启动服务器
const start = async () => {
  try {
    const port = Number(process.env.PORT) || 3000
    const host = process.env.HOST || '0.0.0.0'
    
    // 确保 Prisma 客户端已生成
    await prisma.$connect()
    fastify.log.info('数据库连接成功')
    
    await fastify.listen({ port, host })
    fastify.log.info(`🚀 服务器运行在 http://${host}:${port}`)
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}

start()
