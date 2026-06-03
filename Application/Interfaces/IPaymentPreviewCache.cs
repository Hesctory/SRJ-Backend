using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IPaymentPreviewCache
{
    string Store(CachedPaymentPlan plan);
    bool TryGet(string token, out CachedPaymentPlan? plan);
    void Remove(string token);
}
