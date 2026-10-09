import { Body, Controller, Delete, Get, HttpCode, Inject, Param, ParseUUIDPipe, Post, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';

import { AuthService, loginSchema, registerSchema } from '../auth/auth.service';
import { EmailFlows } from '../auth/email-flows';
import { AuthGuard, CurrentUser } from '../auth/guard';
import type { AuthUser } from '../auth/tokens';
import { ChildrenService } from '../children/children';
import { GamePlanService } from '../children/plan';
import { SharingService } from '../children/sharing';
import { ConsentService } from '../consents/consents';
import { GdprService } from '../gdpr/gdpr';
import { parseWith } from '../common/validation';
import { AskFlow } from '../reports/ask';
import { SummaryFlow } from '../reports/summary-flow';
import { SyncService } from '../sync/sessions';

const refreshSchema = z.object({ refreshToken: z.string().min(20).max(200) }).strict();

/** Conturi doar pentru adulți (ADR-012). */
@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    @Inject(AuthService) private readonly auth: AuthService,
    @Inject(EmailFlows) private readonly mail: EmailFlows,
  ) {}

  @Post('register')
  register(@Body() body: unknown) {
    return this.auth.register(parseWith(registerSchema, body));
  }

  @Post('login')
  @HttpCode(200)
  login(@Body() body: unknown) {
    return this.auth.login(parseWith(loginSchema, body));
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

  /** Legătura din e-mailul de confirmare (fără autentificare: se poate deschide pe alt dispozitiv). */
  @Post('verify-email')
  @HttpCode(200)
  verifyEmail(@Body() body: unknown) {
    return this.mail.verify(body);
  }

  /** „Am uitat parola”: răspunde la fel pentru orice adresă. */
  @Post('password/forgot')
  @HttpCode(202)
  forgot(@Body() body: unknown) {
    return this.mail.forgot(body);
  }

  @Post('password/reset')
  @HttpCode(200)
  reset(@Body() body: unknown) {
    return this.mail.reset(body);
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
    @Inject(SharingService) private readonly sharing: SharingService,
    @Inject(GdprService) private readonly gdpr: GdprService,
    @Inject(GamePlanService) private readonly plan: GamePlanService,
    @Inject(AskFlow) private readonly questions: AskFlow,
  ) {}

  /** Planul de jocuri (plan §5.1): părintele sau specialistul cu partajare activă aleg ce vede copilul. */
  @Get(':childId/plan')
  getPlan(@CurrentUser() user: AuthUser, @Param('childId', ParseUUIDPipe) childId: string) {
    return this.plan.get(user, childId);
  }

  @Put(':childId/plan')
  putPlan(@CurrentUser() user: AuthUser, @Param('childId', ParseUUIDPipe) childId: string, @Body() body: unknown) {
    return this.plan.put(user, childId, body);
  }

  /** Ștergerea profilului copilului (GDPR art. 17): acces tăiat acum, ștergere definitivă în 7 zile. */
  @Delete(':childId')
  @HttpCode(202)
  remove(@CurrentUser() user: AuthUser, @Param('childId', ParseUUIDPipe) childId: string) {
    return this.gdpr.deleteChild(user, childId);
  }

  /** Partajarea cu specialistul (CareLink): doar părintele, cu consimțământ, pe termen limitat. */
  @Get(':childId/share')
  shares(@CurrentUser() user: AuthUser, @Param('childId', ParseUUIDPipe) childId: string) {
    return this.sharing.list(user, childId);
  }

  @Post(':childId/share')
  @HttpCode(200)
  share(@CurrentUser() user: AuthUser, @Param('childId', ParseUUIDPipe) childId: string, @Body() body: unknown) {
    return this.sharing.share(user, childId, body);
  }

  @Delete(':childId/share/:therapistId')
  @HttpCode(204)
  async unshare(
    @CurrentUser() user: AuthUser,
    @Param('childId', ParseUUIDPipe) childId: string,
    @Param('therapistId', ParseUUIDPipe) therapistId: string,
  ): Promise<void> {
    await this.sharing.revoke(user, childId, therapistId);
  }

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

  /** „Întreabă despre progres”: răspuns AI din datele agregate (nu se salvează nimic). */
  @Post(':childId/ask')
  @HttpCode(200)
  ask(@CurrentUser() user: AuthUser, @Param('childId', ParseUUIDPipe) childId: string, @Body() body: unknown) {
    return this.questions.ask(user, childId, body);
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

/** Datele mele (GDPR art. 15, 20): export complet, citibil de mașină. */
@ApiTags('gdpr')
@ApiBearerAuth()
@UseGuards(AuthGuard)
@Controller('me')
export class MeController {
  constructor(
    @Inject(GdprService) private readonly gdpr: GdprService,
    @Inject(AuthService) private readonly auth: AuthService,
    @Inject(EmailFlows) private readonly mail: EmailFlows,
  ) {}

  /** Contul: adresa și dacă e confirmată. */
  @Get()
  account(@CurrentUser() user: AuthUser) {
    return this.auth.account(user);
  }

  /** Retrimite legătura de confirmare a adresei. */
  @Post('verify-email')
  @HttpCode(202)
  resendVerification(@CurrentUser() user: AuthUser) {
    return this.mail.requestVerification(user);
  }

  /** Autentificarea în doi pași (TOTP): starea, configurarea, activarea, oprirea. */
  @Get('2fa')
  totp(@CurrentUser() user: AuthUser) {
    return this.auth.totpStatus(user);
  }

  @Post('2fa/setup')
  @HttpCode(200)
  totpSetup(@CurrentUser() user: AuthUser) {
    return this.auth.setupTotp(user);
  }

  @Post('2fa/enable')
  @HttpCode(200)
  totpEnable(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    return this.auth.enableTotp(user, body);
  }

  @Post('2fa/disable')
  @HttpCode(200)
  totpDisable(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    return this.auth.disableTotp(user, body);
  }

  @Get('export')
  export(@CurrentUser() user: AuthUser) {
    return this.gdpr.export(user);
  }

  /** Ștergerea contului (GDPR art. 17): cere parola; acces tăiat acum, ștergere definitivă în 7 zile.
   *  POST, nu DELETE: corpul (parola) trece sigur prin orice proxy. */
  @Post('delete')
  @HttpCode(202)
  remove(@CurrentUser() user: AuthUser, @Body() body: unknown) {
    return this.gdpr.deleteAccount(user, body);
  }
}
