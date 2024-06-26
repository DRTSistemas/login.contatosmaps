import 'server-only'

import { ResetPasswordTemplate } from './templates/reset-password'
import { render } from '@react-email/render'
import { env } from '@/env'
import { EMAIL_SENDER } from '@/lib/constants'
import { createTransport, type TransportOptions } from 'nodemailer'
import type { ComponentProps } from 'react'

export enum EmailTemplate {
  PasswordReset = 'PasswordReset',
}

export type PropsMap = {
  [EmailTemplate.PasswordReset]: ComponentProps<typeof ResetPasswordTemplate>
}

const getEmailTemplate = <T extends EmailTemplate>(
  template: T,
  props: PropsMap[NoInfer<T>],
) => {
  switch (template) {
    case EmailTemplate.PasswordReset:
      return {
        subject: 'Redefinir sua senha',
        body: render(
          <ResetPasswordTemplate
            {...(props as PropsMap[EmailTemplate.PasswordReset])}
          />,
        ),
      }
    default:
      throw new Error('Invalid email template')
  }
}

const smtpConfig = {
  host: env.SMTP_HOST,
  port: env.SMTP_PORT,
  auth: {
    user: env.SMTP_USER,
    pass: env.SMTP_PASSWORD,
  },
}

const transporter = createTransport(smtpConfig as TransportOptions)

export const sendMail = async <T extends EmailTemplate>(
  to: string,
  template: T,
  props: PropsMap[NoInfer<T>],
) => {
  if (env.NODE_ENV !== 'production') {
    console.log(
      '📨 Email sent to:',
      to,
      'with template:',
      template,
      'and props:',
      props,
    )
    return
  }

  const { subject, body } = getEmailTemplate(template, props)

  return transporter.sendMail({ from: EMAIL_SENDER, to, subject, html: body })
}
