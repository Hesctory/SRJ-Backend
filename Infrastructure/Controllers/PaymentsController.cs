using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api")]
public class PaymentsController : ControllerBase
{
    private readonly CreatePaymentPreviewUseCase _previewUseCase;
    private readonly ConfirmPaymentUseCase _confirmUseCase;

    public PaymentsController(
        CreatePaymentPreviewUseCase previewUseCase,
        ConfirmPaymentUseCase confirmUseCase)
    {
        _previewUseCase = previewUseCase;
        _confirmUseCase = confirmUseCase;
    }

    [HttpPost("payment-preview")]
    [Authorize(Policy = "payment.create")]
    public async Task<IActionResult> Preview([FromBody] PaymentPreviewRequestDTO dto)
    {
        var result = await _previewUseCase.ExecuteAsync(dto);
        return Ok(result);
    }

    [HttpPost("payments")]
    [Authorize(Policy = "payment.create")]
    public async Task<IActionResult> Confirm([FromBody] ConfirmPaymentRequestDTO dto)
    {
        var result = await _confirmUseCase.ExecuteAsync(dto.PreviewToken);
        return Ok(result);
    }
}
