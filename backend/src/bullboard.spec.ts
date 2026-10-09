import type { NextFunction, Request, Response } from 'express';

import { basicAuth } from './bullboard';

function call(header?: string) {
  const res = { status: jest.fn().mockReturnThis(), setHeader: jest.fn().mockReturnThis(), send: jest.fn() };
  const next = jest.fn();
  basicAuth('parola-cozi')({ headers: { authorization: header } } as Request, res as unknown as Response, next as NextFunction);
  return { res, next };
}

describe('Bull Board: parola', () => {
  const b64 = (s: string) => `Basic ${Buffer.from(s).toString('base64')}`;

  it('lasă doar admin cu parola corectă', () => {
    expect(call(b64('admin:parola-cozi')).next).toHaveBeenCalled();
    expect(call(b64('admin:gresit')).res.status).toHaveBeenCalledWith(401);
    expect(call(b64('altul:parola-cozi')).next).not.toHaveBeenCalled();
    expect(call().res.setHeader).toHaveBeenCalledWith('WWW-Authenticate', expect.stringContaining('Basic'));
  });
});
