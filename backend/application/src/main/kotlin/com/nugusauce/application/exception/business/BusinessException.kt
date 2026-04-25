package com.nugusauce.application.exception.business

import com.nugusauce.application.exception.ApplicationException
import com.nugusauce.application.exception.ErrorCode

open class BusinessException(
    val errorCode: ErrorCode,
    val detail: Any? = null,
    val customMessage: String? = null,
    message: String = customMessage ?: errorCode.messageKey
) : ApplicationException(message)
