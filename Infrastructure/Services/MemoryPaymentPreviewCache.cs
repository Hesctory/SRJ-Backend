using Microsoft.Extensions.Caching.Memory;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Services;

public class MemoryPaymentPreviewCache : IPaymentPreviewCache
{
    private readonly IMemoryCache _cache;

    public MemoryPaymentPreviewCache(IMemoryCache cache)
    {
        _cache = cache;
    }

    public string Store(CachedPaymentPlan plan)
    {
        var token = Guid.NewGuid().ToString("N");
        _cache.Set($"payment_preview_{token}", plan, TimeSpan.FromMinutes(5));
        return token;
    }

    public bool TryGet(string token, out CachedPaymentPlan? plan)
        => _cache.TryGetValue($"payment_preview_{token}", out plan);

    public void Remove(string token)
        => _cache.Remove($"payment_preview_{token}");
}
