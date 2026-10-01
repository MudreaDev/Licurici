import { Body, Controller, Get, HttpCode, Inject, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';

import { AuthService, credentialsSchema, registerSchema } from '../auth/auth.service';
import { AuthGuard, CurrentUser } from '../auth/guard';
import type { AuthUser } from '../auth/tokens';
import { ChildrenService } from '../children/children';
import { ConsentService } from '../consents/consents';
import { parseWith } from '../common/validation';
import { SummaryFlow } from '../reports/summary-flow';
import { SyncService } from '../sync/sessions';

const refreshSchema = z.object({ refreshToken: z.string().min(20).max(200) }).strict();

/** Conturi doar pentru adulți (ADR-012). */
@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(@Inject(AuthService) private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() body: unknown) {
    return this.auth.register(parseWith(registerSchema, body));
  }

  @Post('login')
  @HttpCode(200)
  login(@Body() body: unknown) {
    return this.auth.login(parseWith(credentialsSchema, body));
  }

  @Post('refresh')
  @HttpCode(200)
  refresh(@Body() body: unknown) {
    return this.auth.refresh(parseWith(refreshSchema, body).refreshToken);
  }

  @Post('logout')
  @HttpCode(204)
  async logout(@Body() body: unknown): Promise<void> {
    await this.auth.logout(parseWith(refreshSchema, body).refreshToken);
  }
}

/** Copiii, sesiunile lor și rezumatele (README §12). */
@ApiTags('children')
@ApiBearerAuth()
@UseGuards(AuthGuard)
@Controller('children')
export class ChildrenController {
  constructor(
    @Inject(ChildrenService) private readonly children: ChildrenService,
    @Inject(SyncService) private readonly sync: SyncService,
    @Inject(SummaryFlow) private readonly summaries: SummaryFlow,
  ) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.children.list(user);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    return this.children.create(user, body);
  }

  /** Sincronizarea de pe tabletă (outbox, ADR-011): idempotentă după id-ul sesiunii. */
  @Post(':childId/sessions')
  @HttpCode(200)
  push(@CurrentUser() user: AuthUser, @Param('childId', ParseUUIDPipe) childId: string, @Body() body: unknown) {
    return this.sync.push(user, childId, body);
  }

  @Get(':childId/sessions')
  sessions(@CurrentUser() user: AuthUser, @Param('childId', ParseUUIDPipe) childId: string) {
    return this.sync.list(user, childId);
  }

  /** Rezumatul AI (ADR-029): consimțământ, cache, limită zilnică. */
  @Post(':childId/sessions/:sessionId/summary')
  @HttpCode(200)
  summary(
    @CurrentUser() user: AuthUser,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
  ) {
    return this.summaries.summary(user, childId, sessionId);
  }
}

/** Consimțămintele părintelui (README §13, GDPR art. 7–8): jurnal append-only, retragere oricând. */
@ApiTags('consents')
@ApiBearerAuth()
@UseGuards(AuthGuard)
@Controller('consents')
export class ConsentsController {
  constructor(@Inject(ConsentService) private readonly consents: ConsentService) {}

  @Get()
  get(@CurrentUser() user: AuthUser) {
    return this.consents.get(user);
  }

  @Post()
  @HttpCode(200)
  set(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    return this.consents.set(user, body);
  }
}
