using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/lunch-payments")]
public class LunchPaymentsController : ControllerBase
{
    private readonly RecordLunchPaymentUseCase _recordUseCase;

    public LunchPaymentsController(RecordLunchPaymentUseCase recordUseCase)
    {
        _recordUseCase = recordUseCase;
    }

    [HttpPost]
    [Authorize(Policy = "lunch-payment.create")]
    public async Task<IActionResult> Record([FromBody] RecordLunchPaymentDTO dto)
    {
        var result = await _recordUseCase.ExecuteAsync(dto);
        return Ok(result);
    }
}
