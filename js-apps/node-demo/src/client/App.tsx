import { useState, useEffect } from 'react'
import "./index.css";
import logo from "./logo.svg";

interface Record {
  id: number;
  title: string;
  content: string;
  created_at: string;
}

export function App() {
  const [records, setRecords] = useState<Record[]>([]);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  // 获取记录列表
  const fetchRecords = async () => {
    try {
      const response = await fetch('/api/records');
      const result = await response.json();
      if (result.success) {
        setRecords(result.data);
      }
    } catch (error) {
      console.error('获取记录失败:', error);
    }
  };

  // 添加记录
  const addRecord = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      setMessage('请填写标题');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch('/api/records', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ title, content }),
      });

      const result = await response.json();
      if (result.success) {
        setTitle('');
        setContent('');
        setMessage('记录添加成功！');
        fetchRecords(); // 刷新列表
      } else {
        setMessage('添加失败：' + result.error);
      }
    } catch (error) {
      setMessage('添加失败：' + error);
    } finally {
      setLoading(false);
      setTimeout(() => setMessage(''), 3000);
    }
  };

  // 页面加载时获取记录
  useEffect(() => {
    fetchRecords();
  }, []);

  return (
    <div className="app">
      <div className="logo-container">
        <img src={logo} alt="Bun Logo" className="logo bun-logo" />
      </div>

      <h1>Node.js + Fastify + React + PostgreSQL Demo</h1>
      
      {/* 添加记录表单 */}
      <div className="card">
        <h2>📝 添加新记录</h2>
        <form onSubmit={addRecord} style={{ display: 'flex', flexDirection: 'column', gap: '10px', maxWidth: '400px', margin: '0 auto' }}>
          <input
            type="text"
            placeholder="请输入标题"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ccc' }}
          />
          <textarea
            placeholder="请输入内容（可选）"
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={3}
            style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ccc', resize: 'vertical' }}
          />
          <button type="submit" disabled={loading} style={{ padding: '10px', borderRadius: '4px', border: 'none', backgroundColor: '#007acc', color: 'white', cursor: loading ? 'not-allowed' : 'pointer' }}>
            {loading ? '添加中...' : '添加记录'}
          </button>
        </form>
        {message && <p style={{ color: message.includes('成功') ? 'green' : 'red', marginTop: '10px' }}>{message}</p>}
      </div>

      {/* 记录列表 */}
      <div className="card">
        <h2>📋 记录列表 ({records.length} 条)</h2>
        <button onClick={fetchRecords} style={{ marginBottom: '15px', padding: '5px 10px', borderRadius: '4px', border: '1px solid #ccc', backgroundColor: '#f5f5f5', cursor: 'pointer' }}>
          🔄 刷新列表
        </button>
        
        {records.length === 0 ? (
          <p style={{ color: '#666', fontStyle: 'italic' }}>暂无记录，添加第一条记录吧！</p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', maxHeight: '400px', overflowY: 'auto' }}>
            {records.map((record) => (
              <div key={record.id} style={{ border: '1px solid #ddd', borderRadius: '8px', padding: '15px', backgroundColor: '#f9f9f9', textAlign: 'left' }}>
                <h3 style={{ margin: '0 0 8px 0', color: '#333' }}>{record.title}</h3>
                {record.content && <p style={{ margin: '0 0 8px 0', color: '#666' }}>{record.content}</p>}
                <small style={{ color: '#999' }}>
                  创建时间: {new Date(record.created_at).toLocaleString('zh-CN')}
                </small>
              </div>
            ))}
          </div>
        )}
      </div>

      <p className="read-the-docs">
        点击上面的 Bun logo 了解更多
      </p>
    </div>
  );
}

export default App;
